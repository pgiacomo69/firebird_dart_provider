import 'dart:io';
import 'dart:ffi'  as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io' show Platform;
import 'dart:convert' show utf8;
import 'package:fb_connector/src/client/base_db_provider.dart';
import 'package:fb_connector/src/ffi/fb_ffi_extensions.dart';
import 'package:fb_connector/src/ffi/fb_bindings.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

part 'fb_types.dart';
part 'fb_utils.dart';
part 'fb_connection.dart';
part 'fb_transaction.dart';


class FbProvider
    extends BaseDbProvider<FirebirdBindings,FbConnection, FbTransaction> {
   int port;
  String charset;
  int dialect;
  FbServerType serverType; //  = FbServerType.Default,
  FbWireCrypt wireCrypt; // = FbWireCrypt.Disabled

  String role;
  bool useUnicode;
  late final  ffi.DynamicLibrary dylib;
  final _status = calloc<ISC_STATUS>(ISC_STATUS_LENGTH);

  FbProvider(
      {String dataSource = '',
      String database = '',
      String userId = '',
      String password = '',
      bool connectNow = false,
      String  libraryPath='',
      this.port = 3050,
      this.charset = 'NONE',
      this.dialect = 3,
      this.serverType = FbServerType.server,
      this.wireCrypt = FbWireCrypt.disabled,
      this.useUnicode = false,
      this.role = ''})
      : super(
            dataSource: dataSource,
            database: database,
            userId: userId,
            password: password,
            connectNow: connectNow,
            libraryPath:libraryPath);

  void setLibraryPath() {
      if (libraryPath =='') {
      if (Platform.isMacOS) {
        libraryPath ='libfbclient.dylib'; // path.join(Directory.current.path, 'libfbclient.dylib');
      }
      if (Platform.isWindows) {
        libraryPath ='fbclient.dll'; // path.join(Directory.current.path,  'fbclient.dll');
      }
      if (Platform.isLinux) {
        libraryPath = 'libfbclient.so'; // path.join(Directory.current.path, 'libfbclient.so');
      }
    }
 }

  @override
  bool prepareClient() {
    setLibraryPath();
    if (libraryPath != "") {
      dylib = ffi.DynamicLibrary.open(libraryPath!);
      bindings = FirebirdBindings(dylib);

      return true;
    }
    return false;
  }

  @override
  String getDbName() {
    if (dataSource != '') {
      return "$dataSource/$port:$database";
    }
    return database;
  }

   @override
   FbConnection getNewConnection(){
     return FbConnection(provider: this);
   }

   @override
   FbTransaction getNewTransaction({TrIsolationLevel isolationLevel=TrIsolationLevel.readCommitted,bool readOnly=false}){
     return FbTransaction(provider: this,isolationLevel: isolationLevel, readOnly:readOnly);
   }

   @override
  bool disconnect() {
    // TODO: implement disconnect
    throw UnimplementedError();
  }


  void getFbError(int result,ffi.Pointer<ISC_STATUS> status) {
    errorCode = fixnum.Int32(bindings.isc_sqlcode(status)).toInt();
    errorNumber = status.value;
    const int msgLen = 1024 * 4;
    ffi.Pointer<ISC_SCHAR> msgBuf =calloc<ISC_SCHAR>(msgLen);
    try {
      bindings.isc_sql_interprete(errorCode, msgBuf, msgLen);
      sqlErrorMsg = msgBuf.toDartString();
    } finally {
      calloc.free(msgBuf);
    }
    msgBuf = calloc<ISC_SCHAR>(msgLen);
    errorMsg = '';
    final pStatusVector = calloc<ffi.Pointer<ISC_STATUS>>(ISC_STATUS_LENGTH);

    pStatusVector.value = status;
    while (bindings.isc_interprete(msgBuf, pStatusVector) > 0) {
      if (errorMsg != '') errorMsg += '\n';
      errorMsg += msgBuf.toDartString();
    }
    calloc.free(msgBuf);
    calloc.free(pStatusVector);
    print('FbProvider Result:$result\nErrorCode\n$errorCode\nErrorNumber:$errorNumber\n$errorMsg\n$sqlErrorMsg');
  }

  @override
  bool executeSqlInternal(String sql,BaseDbTransaction transaction){
     bool result = false;
     var _str=FirebirdUtils.stringToCharPointer(sql);

     try {
       var res=bindings.isc_dsql_execute_immediate(_status, currentConnection!.handler, transaction.handler, sql.length, _str, dialect, ffi.nullptr);
       if (res == 0) {
         resetError();
         result = true;
       } else {
         getFbError(res,_status);
       }
     } finally {
       calloc.free(_str);
     }
     return result;
   }



}
