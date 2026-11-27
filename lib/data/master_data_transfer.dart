import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

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
    final archive=ZipDecoder().decodeBytes(bytes);
    final workbookFile=archive.findFile('xl/workbook.xml');
    final relsFile=archive.findFile('xl/_rels/workbook.xml.rels');
    if(workbookFile==null||relsFile==null)throw const FormatException('Invalid XLSX workbook structure');
    final workbook=XmlDocument.parse(utf8.decode(List<int>.from(workbookFile.content as List)));
    final rels=XmlDocument.parse(utf8.decode(List<int>.from(relsFile.content as List)));
    final sheets=workbook.findAllElements('sheet').toList();
    if(sheets.isEmpty)throw const FormatException('The XLSX workbook has no sheets');
    final relationId=sheets.first.getAttribute('id',namespace:'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
    if(relationId==null)throw const FormatException('The first XLSX sheet has no relationship');
    String? target;
    for(final rel in rels.findAllElements('Relationship')){if(rel.getAttribute('Id')==relationId){target=rel.getAttribute('Target');break;}}
    if(target==null)throw const FormatException('The first XLSX sheet could not be located');
    final sheetPath=target.startsWith('/')?target.substring(1):'xl/'+target;
    final sheetFile=archive.findFile(sheetPath);
    if(sheetFile==null)throw const FormatException('The first XLSX sheet is missing');
    final sheet=XmlDocument.parse(utf8.decode(List<int>.from(sheetFile.content as List)));
    final shared=<String>[];
    final sharedFile=archive.findFile('xl/sharedStrings.xml');
    if(sharedFile!=null){
      final sharedDoc=XmlDocument.parse(utf8.decode(List<int>.from(sharedFile.content as List)));
      for(final item in sharedDoc.findAllElements('si')){shared.add(item.innerText);}
    }
    final result=<List<String>>[];
    for(final rowElement in sheet.findAllElements('row')){
      final cells=<int,String>{};var fallbackColumn=0;
      for(final cell in rowElement.findAllElements('c')){
        final reference=cell.getAttribute('r')??'';
        final column=_columnIndex(reference);
        final index=column<0?fallbackColumn:column;fallbackColumn=index+1;
        final type=cell.getAttribute('t')??'';
        String value='';
        if(type=='inlineStr'){value=cell.findAllElements('t').map((e)=>e.innerText).join();}
        else{
          final raw=cell.getElement('v')?.innerText??'';
          if(type=='s'){final sharedIndex=int.tryParse(raw);if(sharedIndex!=null&&sharedIndex>=0&&sharedIndex<shared.length)value=shared[sharedIndex];}
          else if(type=='b'){value=raw=='1'?'TRUE':'FALSE';}
          else{value=raw;}
        }
        cells[index]=value;
      }
      if(cells.isEmpty){result.add([]);continue;}
      final max=cells.keys.reduce((a,b)=>a>b?a:b);
      result.add(List<String>.generate(max+1,(i)=>cells[i]??''));
    }
    return result;
  }

  static int _columnIndex(String reference) {
    final letters=RegExp(r'^[A-Za-z]+').firstMatch(reference)?.group(0);
    if(letters==null)return -1;
    var value=0;
    for(final code in letters.toUpperCase().codeUnits){value=value*26+(code-64);}
    return value-1;
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
    final archive=Archive();
    final sheetRows=<String>[];
    for(var rowIndex=0;rowIndex<=rows.length;rowIndex++){
      final values=rowIndex==0?headers:headers.map((h)=>rows[rowIndex-1][h]??'').toList();
      final cells=<String>[];
      for(var col=0;col<values.length;col++){
        final ref=_cellReference(col,rowIndex+1);
        cells.add('<c r="'+ref+'" t="inlineStr"><is><t>'+_xmlEscape(values[col])+'</t></is></c>');
      }
      sheetRows.add('<row r="'+(rowIndex+1).toString()+'">'+cells.join()+'</row>');
    }
    final sheetXml='<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'+sheetRows.join()+'</sheetData></worksheet>';
    _addFile(archive,'[Content_Types].xml','''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>''');
    _addFile(archive,'_rels/.rels','''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''');
    _addFile(archive,'xl/workbook.xml','''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Data" sheetId="1" r:id="rId1"/></sheets></workbook>''');
    _addFile(archive,'xl/_rels/workbook.xml.rels','''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>''');
    _addFile(archive,'xl/worksheets/sheet1.xml',sheetXml);
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static void _addFile(Archive archive,String path,String value) {
    final data=utf8.encode(value);archive.addFile(ArchiveFile(path,data.length,data));
  }

  static String _cellReference(int column,int row) {
    var n=column+1;var letters='';
    while(n>0){final rem=(n-1)%26;letters=String.fromCharCode(65+rem)+letters;n=(n-1)~/26;}
    return letters+row.toString();
  }

  static String _xmlEscape(String value)=>value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'","&apos;");

  static String _csvCell(String value) {
    if(value.contains(',')||value.contains('"')||value.contains('\n')||value.contains('\r'))return '"'+value.replaceAll('"','""')+'"';
    return value;
  }

  static Future<void> shareExport({required Uint8List bytes,required String filename,required bool csv}) async {
    final mime=csv?'text/csv':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    await Share.shareXFiles([XFile.fromData(bytes,name:filename,mimeType:mime)],text:filename);
  }
}
