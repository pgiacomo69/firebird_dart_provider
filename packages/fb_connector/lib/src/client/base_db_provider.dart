import 'package:fb_connector/src/client/base_db_provider.dart';

enum TrIsolationLevel {
  readCommitted,
  readUnCommitted,
  repeatableRead,
  isolated,
  snapshot,
  custom
}

abstract class BaseDbClass {
  void dispose();
}

abstract class BaseDbProvider<DbBindingsType, DbConnType extends BaseDbConnection,
    DbTransType extends BaseDbTransaction> extends BaseDbClass {
  String dataSource;
  String database;
  String password;
  String userId;
  String? libraryPath;
  DbConnType? currentConnection;
  DbTransType? currentTransaction;
  late final DbBindingsType bindings;

  late String errorMsg;
  late String sqlErrorMsg;
  late int errorNumber;
  late int errorCode;

  BaseDbProvider(
      {this.dataSource = '',
      this.database = '',
      this.userId = '',
      this.password = '',
      this.libraryPath = '',
      bool connectNow = false}) {
    errorMsg = '';
    sqlErrorMsg = '';
    errorNumber = 0;
    errorCode = 0;
    prepareClient();
    if (connectNow) {
      connect();
    }
  }

  bool get connected {
    return isConnected();
  }

  set connected(bool value) {
    if (value) {
      if (!isConnected()) connect();
    } else {
      if (isConnected()) disconnect();
    }
  }

  String getDbName();
  bool prepareClient();

  bool connect() {
    bool result = false;
    if (currentConnection == null) {
      final DbConnType conn = getNewConnection();
      if (conn.connect()) {
        currentConnection = conn;
        currentTransaction=startTransaction();
        result=true;
      } else {
        conn.dispose();
      }
    }
    return result;
  }

  DbTransType? startTransaction({bool readOnly=false,
    TrIsolationLevel isolationLevel = TrIsolationLevel.readCommitted}){
     DbTransType? trans = getNewTransaction(isolationLevel: isolationLevel,readOnly: readOnly);
      if (trans.start()) {
        currentTransaction = trans;

      } else {
        trans.dispose();
        trans=null;
      }
    return trans;
}



  DbConnType getNewConnection();

  void disposeConnection() {
    if (currentConnection != null) {
      try {
        currentConnection!.dispose();
      } finally {
        currentConnection = null;
      }
    }
  }

  DbTransType getNewTransaction({TrIsolationLevel isolationLevel=TrIsolationLevel.readCommitted,bool readOnly=false});

  void disposeTransaction() {
    if (currentTransaction != null) {
      try {
        currentConnection!.dispose();
      } finally {
        currentTransaction = null;
      }
    }
  }

  bool executeSqlInternal(String sql,BaseDbTransaction transaction);

  bool executeSql(String sql,{BaseDbTransaction? transaction,}){
    bool result=false;
    bool singleTransaction=false;
    if (transaction==null) {
      transaction=currentTransaction;
      if (transaction==null) {
        transaction=getNewTransaction()..start();
        singleTransaction = true;
      }
      if (transaction.active) {
        result=executeSqlInternal(sql,transaction);
      }
    }
    if (singleTransaction)
      {
        switch (result) {
          case true:
          transaction.commit(renew: true);
          break;
          case false:
            transaction.rollback(renew: true);
          }
          transaction.dispose();
      }
    return result;
  }

  bool disconnect() {
    bool result = false;
    try {
      if (connected) {
        currentConnection!.disconnect();
        result = true;
      }
    } finally {
      disposeConnection();
    }
    return result;
  }

  void resetError() {
    errorCode = 0;
    errorNumber = 0;
    errorMsg = '';
    sqlErrorMsg = '';
  }




  bool isConnected() {
    return currentConnection != null;
  }

  @override
  void dispose() {
    if (currentTransaction != null) {
      currentTransaction!.dispose();
    }
    if (currentConnection != null) {
      currentConnection!.dispose();
    }
  }
}

abstract class BaseDbConnection<ProviderType, DbConnType> extends BaseDbClass {
  late DbConnType handler;
  ProviderType provider;
  bool connect();
  bool disconnect();
  BaseDbConnection({required this.provider, required this.handler});
}

abstract class BaseDbTransaction<ProviderType, DbTransType> extends BaseDbClass {
  DbTransType handler;
  TrIsolationLevel isolationLevel;
  ProviderType provider;
  bool readOnly;
  bool get active { return getActive();}

  bool getActive();

  BaseDbTransaction(
      {required this.provider,
      required this.handler,
      this.readOnly=false,
      this.isolationLevel = TrIsolationLevel.readCommitted});
  bool start();
  bool commit({bool renew=false});
  bool rollback({bool renew=false});
}
