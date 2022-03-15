part of 'fb_provider.dart';

class FirebirdUtils {

  static void addDpbField(List<int> currentDpb, int iscType, String value) {
    if (value != '') {
      currentDpb.add(iscType);
      List<int> buf = utf8.encode(value);
      currentDpb.add(buf.length);
      currentDpb.addAll(buf);
    }
  }

  static ffi.Pointer<ISC_SCHAR> arrayToCharPointer(List<int> value) {
    final result = calloc<ISC_SCHAR>(value.length);
    final resultL = result.asTypedList(value.length);
    resultL.setAll(0, value);
    return result;
  }

  static ffi.Pointer<ISC_SCHAR> stringToCharPointer(String value) {
    final _values = utf8.encode(value);
    return FirebirdUtils.arrayToCharPointer(_values);
  }


  static ffi.Pointer<ffi.Void> arrayToVoidPointer(List<int> value) {
    final result =calloc<ffi.Int8>(value.length);
    final resultL = result.asTypedList(value.length);
    resultL.setAll(0, value);
    return result.cast();
  }

  static void resizeArray2048(List<int> a){
    final int aSize = ((a.length ~/ 2048) + 1) * 2048;
    for (int i = a.length; i < aSize; i++) {
      a.add(0);
    }
  }



}