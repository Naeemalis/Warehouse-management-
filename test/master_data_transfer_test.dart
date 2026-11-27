import 'package:flutter_test/flutter_test.dart';
import 'package:naeemsoft_wms/data/master_data_transfer.dart';

void main() {
  test('CSV export/import preserves commas, quotes and Arabic text', () {
    final headers=['name','phone','notes'];
    final rows=[{'name':'مورد, رئيسي','phone':'123','notes':'قال "متاح", نعم'}];
    final bytes=MasterDataTransfer.encodeRows(headers,rows,csv:true);
    final decoded=MasterDataTransfer.readRows(bytes,'sample.csv');
    expect(decoded.single['name'],'مورد, رئيسي');
    expect(decoded.single['notes'],'قال "متاح", نعم');
  });

  test('Excel export/import round-trips master data', () {
    final headers=['name','phone'];
    final rows=[{'name':'عميل تجريبي','phone':'555'}];
    final bytes=MasterDataTransfer.encodeRows(headers,rows,csv:false);
    final decoded=MasterDataTransfer.readRows(bytes,'sample.xlsx');
    expect(decoded.single['name'],'عميل تجريبي');
    expect(decoded.single['phone'],'555');
  });
}
