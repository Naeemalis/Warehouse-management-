import '../domain/unit_conversion.dart';
import 'wms_database.dart';

/// Imports master data only; posted documents, stock, payments and balances are untouched.
extension WmsMasterDataImport on WmsDatabase {
  Future<Map<String,Object?>> importParties({required String table,required List<Map<String,String>> rows}) async {
    if(table!='suppliers'&&table!='customers')throw ArgumentError('Unsupported party table');
    final db=await database;var inserted=0,updated=0,skipped=0;final errors=<String>[];
    await db.transaction((txn) async {
      for(var index=0;index<rows.length;index++){
        final row=rows[index];final name=(row['name']??'').trim();final phone=(row['phone']??'').trim();
        if(name.isEmpty){skipped++;errors.add('Row '+(index+2).toString()+': name is required');continue;}
        try{
          List<Map<String,Object?>> matches=[];
          if(phone.isNotEmpty)matches=await txn.query(table,where:'phone=? AND is_active=1',whereArgs:[phone]);
          if(matches.isEmpty)matches=await txn.query(table,where:'name=? COLLATE NOCASE AND is_active=1',whereArgs:[name]);
          if(matches.length>1){skipped++;errors.add('Row '+(index+2).toString()+': ambiguous duplicate; no changes made');continue;}
          final now=DateTime.now().toIso8601String();
          if(matches.length==1){
            final id=matches.first['id'] as int;
            await txn.update(table,{'name':name,'phone':phone.isEmpty?matches.first['phone']:phone,'address':(row['address']??'').trim().isEmpty?matches.first['address']:(row['address']??'').trim(),'notes':(row['notes']??'').trim().isEmpty?matches.first['notes']:(row['notes']??'').trim()},where:'id=?',whereArgs:[id]);
            await txn.insert('audit_log',{'entity_type':table.substring(0,table.length-1),'entity_id':id,'action':'import_updated','actor_id':null,'details':'Master data updated from import file','created_at':now});updated++;
          }else{
            final id=await txn.insert(table,{'name':name,'phone':phone.isEmpty?null:phone,'address':(row['address']??'').trim().isEmpty?null:(row['address']??'').trim(),'notes':(row['notes']??'').trim().isEmpty?null:(row['notes']??'').trim(),'created_at':now});
            await txn.insert('audit_log',{'entity_type':table.substring(0,table.length-1),'entity_id':id,'action':'import_created','actor_id':null,'details':'Master data created from import file','created_at':now});inserted++;
          }
        }catch(e){skipped++;errors.add('Row '+(index+2).toString()+': '+e.toString());}
      }
    });
    return {'inserted':inserted,'updated':updated,'skipped':skipped,'errors':errors};
  }

  Future<Map<String,Object?>> importProducts(List<Map<String,String>> rows) async {
    final db=await database;var inserted=0,updated=0,skipped=0;final errors=<String>[];
    await db.transaction((txn) async {
      for(var index=0;index<rows.length;index++){
        final row=rows[index];final name=(row['name']??'').trim();final base=(row['base_unit_name']??'').trim();final code=(row['code']??'').trim();
        if(name.isEmpty){skipped++;errors.add('Row '+(index+2).toString()+': name is required');continue;}
        try{
          List<Map<String,Object?>> matches=[];
          if(code.isNotEmpty)matches=await txn.query('products',where:'code=? AND is_active=1',whereArgs:[code]);
          if(matches.isEmpty)matches=await txn.query('products',where:'name=? COLLATE NOCASE AND is_active=1',whereArgs:[name]);
          if(matches.length>1){skipped++;errors.add('Row '+(index+2).toString()+': ambiguous product name/code; no changes made');continue;}
          final now=DateTime.now().toIso8601String();final tracking=(row['tracking_mode']??'count').trim();
          if(!['count','weight','volume'].contains(tracking)){skipped++;errors.add('Row '+(index+2).toString()+': invalid tracking_mode');continue;}
          if(matches.length==1){
            final existing=matches.first;final id=existing['id'] as int;final existingCode=existing['code']?.toString();
            if(code.isNotEmpty&&existingCode!=null&&existingCode!=code){
              final collision=await txn.query('products',where:'code=? AND id<>?',whereArgs:[code,id]);
              if(collision.isNotEmpty){skipped++;errors.add('Row '+(index+2).toString()+': product code belongs to another product');continue;}
            }
            await txn.update('products',{'name':name,'code':code.isEmpty?existingCode:code,'category':(row['category']??'').trim().isEmpty?existing['category']:(row['category']??'').trim(),'updated_at':now},where:'id=?',whereArgs:[id]);
            final definitions=(row['unit_definitions']??'').trim();final baseSale=double.tryParse((row['base_sale_price']??'').trim().replaceAll(',','.'));final supplySale=double.tryParse((row['supply_sale_price']??'').trim().replaceAll(',','.'));
            if(definitions.isNotEmpty&&base.isNotEmpty&&baseSale!=null&&supplySale!=null&&baseSale>0&&supplySale>0){
              final imported=buildHierarchicalUnitDefinitions(baseUnitName:base,baseSalePrice:baseSale,supplySalePrice:supplySale,definitions:definitions.replaceAll(';',','));
              final current=await txn.query('product_units',where:'product_id=? AND is_active=1',whereArgs:[id]);
              var same=current.length==imported.length&&existing['base_unit_name']==base;
              for(final unit in imported){
                final found=current.where((u)=>u['unit_name']==unit['unit_name']).toList();
                if(found.length!=1||((found.first['factor_to_base'] as num).toDouble()-(unit['factor_to_base'] as num).toDouble()).abs()>0.000001||(((found.first['is_purchase_unit'] as num? ?? 0)==1)!=(unit['is_purchase_unit'] as bool? ?? false))){same=false;break;}
              }
              if(same){
                for(final unit in imported){await txn.update('product_units',{'sale_price_minor':unit['sale_price_minor']},where:'product_id=? AND unit_name=?',whereArgs:[id,unit['unit_name']]);}
                final basePrice=imported.firstWhere((u)=>u['unit_name']==base)['sale_price_minor'] as int;
                await txn.update('products',{'issue_price_minor':basePrice},where:'id=?',whereArgs:[id]);
              }else{errors.add('Row '+(index+2).toString()+': metadata updated; existing units and conversion factors were preserved because definitions differ');}
            }else if(base.isNotEmpty&&base!=existing['base_unit_name']){errors.add('Row '+(index+2).toString()+': existing base unit was preserved to protect stock conversion history');}
            await txn.insert('audit_log',{'entity_type':'product','entity_id':id,'action':'import_updated','actor_id':null,'details':'Product master data updated from import file','created_at':now});updated++;
          }else{
            if(base.isEmpty)throw ArgumentError('base_unit_name is required for a new product');
            final definitions=(row['unit_definitions']??'').trim();final baseSale=double.tryParse((row['base_sale_price']??'').trim().replaceAll(',','.'));final supplySale=double.tryParse((row['supply_sale_price']??'').trim().replaceAll(',','.'));
            if(definitions.isEmpty||baseSale==null||supplySale==null||baseSale<=0||supplySale<=0)throw ArgumentError('New products require base/supply sale prices and unit_definitions');
            final units=buildHierarchicalUnitDefinitions(baseUnitName:base,baseSalePrice:baseSale,supplySalePrice:supplySale,definitions:definitions.replaceAll(';',','));
            final id=await txn.insert('products',{'code':code.isEmpty?null:code,'name':name,'category':(row['category']??'').trim().isEmpty?null:(row['category']??'').trim(),'base_unit_name':base,'tracking_mode':tracking,'issue_price_minor':(baseSale*100).round(),'created_at':now,'updated_at':now});
            for(var i=0;i<units.length;i++){
              final unit=units[i];
              await txn.insert('product_units',{'product_id':id,'unit_name':unit['unit_name'],'factor_to_base':unit['factor_to_base'],'sort_order':i,'sale_price_minor':unit['sale_price_minor'],'is_purchase_unit':(unit['is_purchase_unit'] as bool? ?? false)?1:0,'created_at':now});
            }
            await txn.insert('audit_log',{'entity_type':'product','entity_id':id,'action':'import_created','actor_id':null,'details':'Product created from import file','created_at':now});inserted++;
          }
        }catch(e){skipped++;errors.add('Row '+(index+2).toString()+': '+e.toString());}
      }
    });
    return {'inserted':inserted,'updated':updated,'skipped':skipped,'errors':errors};
  }
}
