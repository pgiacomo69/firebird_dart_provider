
part of 'fb_provider.dart';

class FbTeb extends ffi.Struct {
  external ffi.Pointer<isc_db_handle> dbHandle;

  @ffi.Int64()
  external int tpbLength;

  external ffi.Pointer<ISC_SCHAR> tpb;
}


class FbTransaction extends BaseDbTransaction<FbProvider,ffi.Pointer<isc_tr_handle>> {
  FbTransaction({required FbProvider provider,TrIsolationLevel isolationLevel=TrIsolationLevel.readCommitted,bool readOnly=false}) : super(provider:provider, isolationLevel:isolationLevel,readOnly: readOnly, handler: calloc<isc_tr_handle>(4));
  // FirebirdTransaction.fromHandler(Pointer<isc_db_handle> handler):super(handler);
  final _status = calloc<ISC_STATUS>(ISC_STATUS_LENGTH);

  bool _active=false;

  bool get active {
    return _active;
  }

  @override
  bool start() {
    assert(!_active,'Transaction Already Started!');
      final List<int> currentTpb = [isc_tpb_version3];
      switch (isolationLevel) {
        case TrIsolationLevel.repeatableRead:
        case TrIsolationLevel.snapshot:
          currentTpb.add(isc_tpb_concurrency);
          currentTpb.add(isc_tpb_nowait);
          // currentTpb.add(0);
          break;
        case TrIsolationLevel.readCommitted:
          currentTpb.add(isc_tpb_read_committed);
          currentTpb.add(isc_tpb_rec_version);
          currentTpb.add(isc_tpb_nowait);
          // currentTpb.add(0);
          break;
        case TrIsolationLevel.isolated:
          currentTpb.add(isc_tpb_consistency);
          // currentTpb.add(0);
          break;
        case TrIsolationLevel.custom:
          break;
        default:
      }
    switch(readOnly){
      case true:currentTpb.add(isc_tpb_read);
      break;
      case false:currentTpb.add(isc_tpb_write);
      break;
    }
    var tpbLength=currentTpb.length;
    FirebirdUtils.resizeArray2048(currentTpb);
    final teb=calloc<FbTeb>();
      try {
        teb.ref.dbHandle=provider.currentConnection!.handler;
        teb.ref.tpbLength=tpbLength;
        teb.ref.tpb=FirebirdUtils.arrayToCharPointer(currentTpb);

        ffi.Pointer<ffi.Void> pTeb=teb.cast();
        final res = provider.bindings.isc_start_multiple(
            _status,handler, 1, pTeb);
        if (res == 0) {
          provider.resetError();
          _active=true;
        } else {
          provider.getFbError(res,_status);
        }
      } catch (e) {
        print(e.toString());
      }
      calloc.free(teb.ref.tpb);
      calloc.free(teb);
      return _active;
    }

  @override
  bool commit({bool renew=false}) {
    if (!_active) { return false;}
    bool result = false;
    try {
      var res = provider.bindings.isc_commit_transaction(
          _status,  handler);
      if (res == 0) {
        provider.resetError();
        result = true;
      } else {
        provider.getFbError(res,_status);
      }
    } finally {
      if (result && renew) {
          handler.value=0;
          _active=start();
        }
      else {
        _active=false;
      }
       if (_active) {
         calloc.free(handler);
       }
    }
    return result;
  }

  @override
  bool rollback({bool renew=false}){
    if (!_active) { return false;}
    bool result = false;
    try {
      var res = provider.bindings.isc_rollback_transaction(
          _status,  handler);
      if (res == 0) {
        provider.resetError();
        result = true;
      } else {
        provider.getFbError(res,_status);
      }
    } finally {
      if (result && renew) {
        handler.value=0;
        _active=start();
      }
      else {
        _active=false;
      }
      if (_active) {
        calloc.free(handler);
      }
    }
    return result;

  }


  @override
  void dispose() {
    if (_active) {
      rollback();
      calloc.free(handler);
    }


  }
}