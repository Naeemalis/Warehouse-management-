import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class MasterDataPickedFile {
  const MasterDataPickedFile({required this.name,required this.bytes});
  final String name;
  final Uint8List bytes;
}

class MasterDataTransfer {
  static Future<MasterDataPickedFile?> pickImportFile() async {
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['xlsx','csv'],withData:true);
    if(result==null||result.files.isEmpty)return null;
    final file=result.files.single;
    final bytes=file.bytes;
    if(bytes==null||bytes.isEmpty)throw const FormatException('The selected file is empty or unreadable');
    return MasterDataPickedFile(name:file.name,bytes:bytes);
  }

  static List<Map<String,String>> readRows(Uint8List bytes,String filename) {
    final extension=filename.toLowerCase().split('.').last;
    final matrix=extension=='csv'?_parseCsv(utf8.decode(bytes,allowMalformed:false).replaceFirst('\uFEFF','')):extension=='xlsx'?_parseXlsx(bytes):throw FormatException('Only .xlsx and .csv files are supported');
    if(matrix.isEmpty)return [];
    final headers=matrix.first.map((v)=>v.trim().toLowerCase()).toList();
    final result=<Map<String,String>>[];
    for(final row in matrix.skip(1)){
      if(row.every((v)=>v.trim().isEmpty))continue;
      final record=<String,String>{};
      for(var i=0;i<headers.length;i++){if(headers[i].isNotEmpty)record[headers[i]]=i<row.length?row[i].trim():'';}
      result.add(record);
    }
    return result;
  }

  static List<List<String>> _parseXlsx(Uint8List bytes) {
    final workbook=Excel.decodeBytes(bytes);
    if(workbook.tables.isEmpty)return [];
    return workbook.tables.values.first.rows.map((row)=>row.map((cell)=>cell?.value?.toString()??'').toList()).toList();
  }

  static List<List<String>> _parseCsv(String source) {
    final rows=<List<String>>[];var row=<String>[];final cell=StringBuffer();var quoted=false;
    for(var i=0;i<source.length;i++){
      final ch=source[i];
      if(ch=='"'){if(quoted&&i+1<source.length&&source[i+1]=='"'){cell.write('"');i++;}else{quoted=!quoted;}}
      else if(ch==','&&!quoted){row.add(cell.toString());cell.clear();}
      else if((ch=='\n'||ch=='\r')&&!quoted){if(ch=='\r'&&i+1<source.length&&source[i+1]=='\n')i++;row.add(cell.toString());cell.clear();if(row.any((v)=>v.isNotEmpty))rows.add(row);row=<String>[];}
      else{cell.write(ch);}
    }
    row.add(cell.toString());if(row.any((v)=>v.isNotEmpty))rows.add(row);
    if(quoted)throw const FormatException('CSV contains an unclosed quoted field');
    return rows;
  }

  static Uint8List encodeRows(List<String> headers,List<Map<String,String>> rows,{required bool csv}) {
    if(csv){
      final lines=<String>[headers.map(_csvCell).join(',')];
      for(final row in rows){lines.add(headers.map((h)=>_csvCell(row[h]??'')).join(','));}
      return Uint8List.fromList(utf8.encode('\uFEFF'+lines.join('\r\n')+'\r\n'));
    }
    final workbook=Excel.createExcel();final sheet=workbook['Sheet1'];
    sheet.appendRow(headers.map((v)=>TextCellValue(v)).toList());
    for(final row in rows){sheet.appendRow(headers.map((h)=>TextCellValue(row[h]??'')).toList());}
    final encoded=workbook.encode();if(encoded==null)throw StateError('Could not encode Excel workbook');
    return Uint8List.fromList(encoded);
  }

  static String _csvCell(String value) {
    if(value.contains(',')||value.contains('"')||value.contains('\n')||value.contains('\r'))return '"'+value.replaceAll('"','""')+'"';
    return value;
  }

  static Future<void> shareExport({required Uint8List bytes,required String filename,required bool csv}) async {
    final mime=csv?'text/csv':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    await Share.shareXFiles([XFile.fromData(bytes,name:filename,mimeType:mime)],text:filename);
  }
}
