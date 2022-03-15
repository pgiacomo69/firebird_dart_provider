part of 'fb_provider.dart';

class FbConnection
    extends BaseDbConnection<FbProvider, ffi.Pointer<isc_db_handle>> {
  FbConnection({required FbProvider provider, bool connectNow = false})
      : super(provider: provider, handler: calloc<isc_db_handle>(4));
  final _status = calloc<ISC_STATUS>(ISC_STATUS_LENGTH);

  List<int> createDpb() {
    String vCharset;
    List<int> currentDpb = [];

    currentDpb.add(isc_dpb_version1);
    if (provider.useUnicode && provider.charset.toUpperCase() != 'UTF8') {
      vCharset = 'UNICODE_FSS';
    } else {
      vCharset = provider.charset;
    }
    FirebirdUtils.addDpbField(currentDpb, isc_dpb_user_name, provider.userId);
    FirebirdUtils.addDpbField(currentDpb, isc_dpb_password, provider.password);
    FirebirdUtils.addDpbField(currentDpb, isc_dpb_lc_ctype, vCharset);
    FirebirdUtils.addDpbField(currentDpb, isc_dpb_sql_role_name, provider.role);
    return currentDpb;
  }

  @override
  bool connect() {
    bool result = false;
    // TODO: implement connect
    final _dbName = utf8.encode(provider.getDbName());
    final _dbNameP = FirebirdUtils.arrayToCharPointer(_dbName);
    final _dpb = createDpb();
    final _dpbLength = _dpb.length;
    FirebirdUtils.resizeArray2048(_dpb);
    final _dpbP = FirebirdUtils.arrayToCharPointer(_dpb);

    try {
      var res = provider.bindings.isc_attach_database(
          _status, _dbName.length, _dbNameP, handler, _dpbLength, _dpbP);
      if (res == 0) {
        provider.resetError();
        result = true;
      } else {
        provider.getFbError(res,_status);
      }
    } finally {
      calloc.free(_dbNameP);
      calloc.free(_dpbP);
    }
    return result;
  }



  @override
  bool disconnect() {
    // TODO: implement disconnect
    return true;
  }

  @override
  void dispose() {
    calloc.free(handler);
    calloc.free(_status);
  }
}
