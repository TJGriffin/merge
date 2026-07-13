/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with duplicate identification and merging
*/
public with sharing class MRG_DuplicateMerge_CTRL {
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static Integer getCount(MRG_Duplicate_SVC.candidateFilter filter){
        // count candidate pairs (the list pages over pairs, grouped for display). COUNT_DISTINCT and
        // GROUP BY aggregate every matching row and throw an uncatchable "Too many query rows" once a
        // candidate set exceeds 50k; a plain COUNT() is governor-safe (uses a single query row).
        // locals below are the bind targets referenced by getWhereClause(filter)
        MRG_Duplicate_SVC.candidateFilter f = filter == null ? new MRG_Duplicate_SVC.candidateFilter() : filter;
        String objectType = f.objectType;
        String ruleName = f.ruleName;
        Decimal confidenceMin = f.confidenceMin;
        Decimal confidenceMax = f.confidenceMax;
        Boolean autoMerge = f.autoMerge;
        List<String> statuses = f.safeStatuses();
        String soqlQuery= 'SELECT COUNT() FROM MergeCandidate__c ';
        soqlQuery+=MRG_Duplicate_SVC.getWhereClause(f);
        return Database.countQuery(soqlQuery);
    }
	/*******************************************************************************************************
	* @description the selectable Status__c filter values (Status__c is Text, not a picklist; deriving
	* values via GROUP BY would re-trip the 50k row limit, so the supported set is enumerated here)
	* @return List<Map<String,String>> label/value option list
	*/
    @AuraEnabled(cacheable=TRUE)
    public static List<Map<String,String>> getStatusOptions(){
        return new List<Map<String,String>>{
            new Map<String,String>{'label'=>'New','value'=>'New'},
            new Map<String,String>{'label'=>'Processed','value'=>'Processed'},
            new Map<String,String>{'label'=>'Accounts Merged','value'=>MRG_AccountMerge_SVC.STATUS_ACCOUNTS_MERGED}
        };
    }
	/*******************************************************************************************************
	* @description the field set selectable for the grid display (#84). Id is always first and
	* CreatedDate + LastModifiedDate always last (system columns); every other accessible field is
	* selectable (any field hidden via the preview settings is excluded entirely). Each selectable field
	* carries its current selected state: the saved per-object configuration if one exists, otherwise the
	* first 10 fields by label. Selection is shared across users via MergeGridConfig__c.
	* @param objectType the SObject type
	* @return gridFieldOptions system lead/trail columns + the selectable field list
	*/
    @AuraEnabled(cacheable=TRUE)
    public static gridFieldOptions getGridFieldOptions(String objectType){
        gridFieldOptions result = new gridFieldOptions();
        result.leadFields = new List<gridFieldOption>();
        result.trailFields = new List<gridFieldOption>();
        result.fields = new List<gridFieldOption>();
        if(String.isBlank(objectType) || Schema.getGlobalDescribe().get(objectType) == null)
            return result;
        Map<String, Schema.SObjectField> fmap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
        Set<String> hidden = hiddenPreviewFields(objectType);
        Set<String> system3 = new Set<String>{'id','createddate','lastmodifieddate'};
        List<gridFieldOption> selectable = new List<gridFieldOption>();
        for(MRG_Merge_SVC.objectField fld:MRG_MergeSettings_CTRL.getObjectFields(objectType, true)){
            String lname = fld.name.toLowerCase();
            if(hidden.contains(lname) || system3.contains(lname))
                continue;
            gridFieldOption o = new gridFieldOption();
            o.name = fld.name; o.label = fld.label; o.type = fld.type;
            o.displayLabel = fld.label + ' (' + fld.name + ')';
            selectable.add(o);
        }
        selectable.sort();
        for(gridFieldOption o:selectable)
            o.selected = false;
        Map<String, gridFieldOption> byName = new Map<String, gridFieldOption>();
        for(gridFieldOption o:selectable)
            byName.put(o.name.toLowerCase(), o);
        // selected fields first, in their saved order (preserves the user's column ordering); when no
        // config is saved, default to the first 10 by label. Unselected fields follow, ordered by label.
        List<String> saved = getSavedFields(objectType);
        List<gridFieldOption> ordered = new List<gridFieldOption>();
        Set<String> used = new Set<String>();
        if(saved != null){
            for(String s:saved){
                String sl = s.toLowerCase();
                if(byName.containsKey(sl) && !used.contains(sl)){
                    gridFieldOption o = byName.get(sl);
                    o.selected = true;
                    ordered.add(o);
                    used.add(sl);
                }
            }
        } else {
            for(Integer i=0;i<Math.min(10, selectable.size());i++){
                selectable[i].selected = true;
                ordered.add(selectable[i]);
                used.add(selectable[i].name.toLowerCase());
            }
        }
        for(gridFieldOption o:selectable){
            if(!used.contains(o.name.toLowerCase()))
                ordered.add(o);
        }
        result.leadFields.add(fieldOption(fmap,'Id'));
        result.fields = ordered;
        result.trailFields.add(fieldOption(fmap,'CreatedDate'));
        result.trailFields.add(fieldOption(fmap,'LastModifiedDate'));
        return result;
    }
	/*******************************************************************************************************
	* @description saves the grid field selection for an object type, shared across all users (#84)
	* @param objectType the SObject type
	* @param fields the selected field API names
	*/
    @AuraEnabled
    public static void saveGridFieldConfig(String objectType, List<String> fields){
        if(String.isBlank(objectType))
            return;
        MergeGridConfig__c cfg = new MergeGridConfig__c(
            ObjectType__c = objectType,
            Fields__c = JSON.serialize(fields == null ? new List<String>() : fields)
        );
        upsert cfg ObjectType__c;
    }
	/*******************************************************************************************************
	* @description the saved grid field selection for an object type, or null if none saved
	*/
    private static List<String> getSavedFields(String objectType){
        List<MergeGridConfig__c> cfgs = [
            SELECT Fields__c FROM MergeGridConfig__c WHERE ObjectType__c =:objectType LIMIT 1
        ];
        if(cfgs.isEmpty() || String.isBlank(cfgs[0].Fields__c))
            return null;
        return (List<String>) JSON.deserialize(cfgs[0].Fields__c, List<String>.class);
    }
	/*******************************************************************************************************
	* @description grid rows (#84) for a set of candidates (the duplicates of the groups currently in
	* view): each kept record's group shows the kept record, its duplicate(s) and the simulated merge
	* result, for the requested display fields. The simulated result reuses the bulk preview engine
	* (MRG_Merge_SVC.getMergeHistoryResult) so a page of visible groups is computed in a single call.
	* Group/within-group paging is handled client-side over getKeepGroups, so only the visible groups'
	* candidates are passed here.
	* @param objectType the SObject type
	* @param fields the ordered display field API names (Id/CreatedDate/LastModifiedDate handled as well)
	* @param candidateIds the merge candidate ids whose groups are currently in view
	* @return gridResponse columns + grouped rows
	*/
    @AuraEnabled
    public static gridResponse getGridRows(String objectType, List<String> fields, List<Id> candidateIds){
        gridResponse resp = new gridResponse();
        resp.columns = new List<gridFieldOption>();
        resp.groups = new List<gridGroup>();
        if(String.isBlank(objectType) || candidateIds == null || candidateIds.isEmpty()
            || Schema.getGlobalDescribe().get(objectType) == null)
            return resp;
        Map<String, Schema.SObjectField> fmap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();

        // resolve display fields (defensive: always Id; drop hidden + unknown fields)
        Set<String> hidden = hiddenPreviewFields(objectType);
        List<String> displayFields = new List<String>{'Id'};
        Set<String> displaySet = new Set<String>{'id'};
        if(fields != null){
            for(String fld:fields){
                if(String.isBlank(fld))
                    continue;
                String l = fld.toLowerCase();
                if(displaySet.contains(l) || hidden.contains(l) || !fmap.containsKey(l))
                    continue;
                displayFields.add(fmap.get(l).getDescribe().getName());
                displaySet.add(l);
            }
        }
        for(String fld:displayFields)
            resp.columns.add(fieldOption(fmap, fld));

        String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL() + ' WHERE Id IN :candidateIds';
        List<MergeCandidate__c> candidates = (List<MergeCandidate__c>) Database.query(soqlQuery);
        if(candidates.isEmpty())
            return resp;

        // bulk fetch the display values for the kept + duplicate records
        Set<Id> recordIds = new Set<Id>();
        for(MergeCandidate__c c:candidates){
            if(String.isNotBlank(c.KeepRecordId__c)) recordIds.add(c.KeepRecordId__c);
            if(String.isNotBlank(c.MergeRecordId__c)) recordIds.add(c.MergeRecordId__c);
            if(String.isNotBlank(c.Merge2RecordId__c)) recordIds.add(c.Merge2RecordId__c);
        }
        Map<Id, SObject> displayMap = new Map<Id, SObject>(
            Database.query('SELECT ' + String.join(displayFields, ',') + ' FROM ' + objectType + ' WHERE Id IN :recordIds'));

        // any saved keep-value overrides, keyed by kept record id (overlaid on the keep row below)
        Map<Id, Map<String,Object>> overridesByKeep = MRG_Merge_SVC.getManualOverridesByKeepId(candidates);

        // simulate the merges once for these candidates; map the result records by kept id
        MRG_Merge_SVC.mergeHistoryResult mr = MRG_Merge_SVC.getMergeHistoryResult(candidates, objectType);
        Map<Id, Map<String,Object>> resultByKeepId = new Map<Id, Map<String,Object>>();
        if(mr != null && mr.updateRecords != null){
            for(SObject u:mr.updateRecords){
                if(u.get('Id') != null)
                    resultByKeepId.put((Id) u.get('Id'), lowerKeyed(u));
            }
        }

        // group by kept record (client controls group ordering/paging)
        Map<String, gridGroup> byKeep = new Map<String, gridGroup>();
        List<String> keepOrder = new List<String>();
        for(MergeCandidate__c c:candidates){
            String keepId = c.KeepRecordId__c;
            if(!byKeep.containsKey(keepId)){
                gridGroup g = new gridGroup();
                g.keepId = keepId;
                g.keepName = c.KeepName__c;
                g.objectType = objectType;
                g.rows = new List<gridRow>();
                if(displayMap.containsKey(keepId))
                    g.rows.add(buildRow('keep', keepId, null, false, displayFields, displayMap.get(keepId)));
                byKeep.put(keepId, g);
                keepOrder.add(keepId);
            }
            gridGroup g = byKeep.get(keepId);
            if(String.isNotBlank(c.MergeRecordId__c) && displayMap.containsKey(c.MergeRecordId__c))
                g.rows.add(buildRow('duplicate', c.MergeRecordId__c, c.Id, true, displayFields, displayMap.get(c.MergeRecordId__c)));
            if(String.isNotBlank(c.Merge2RecordId__c) && displayMap.containsKey(c.Merge2RecordId__c))
                g.rows.add(buildRow('duplicate', c.Merge2RecordId__c, c.Id, true, displayFields, displayMap.get(c.Merge2RecordId__c)));
        }
        for(String keepId:keepOrder){
            gridGroup g = byKeep.get(keepId);
            Id kid = Id.valueOf(keepId);
            g.rows.add(buildResultRow(displayFields, displayMap.get(keepId), resultByKeepId.get(kid), overridesByKeep.get(kid)));
            resp.groups.add(g);
        }
        return resp;
    }
	/*******************************************************************************************************
	* @description runs a grid action (merge / mergeAccounts / remove) over EVERY candidate matching the
	* filter, in the background (#84 "select all maximum"). Returns the AsyncApexJob id.
	* @param filter the candidate filter
	* @param action 'merge' | 'mergeAccounts' | 'remove'
	* @return Id the batch AsyncApexJob id
	*/
    @AuraEnabled
    public static Id runActionOverFilter(MRG_Duplicate_SVC.candidateFilter filter, String action){
        Integer scopeSize = action == 'remove' ? 200 : 20;
        return Database.executeBatch(new MRG_GridAction_BATCH(filter, action), scopeSize);
    }

	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static List<keepGroup> getKeepGroups(MRG_Duplicate_SVC.candidateFilter filter, Integer limitAmt, Integer offsetAmt){
        limitAmt = limitAmt == null ? 200 : limitAmt;
        // page over the candidate pairs directly (highest confidence first) and group them by kept
        // record for display. Avoids GROUP BY/COUNT_DISTINCT, which aggregate every matching row and
        // throw an uncatchable "Too many query rows" once a candidate set exceeds 50k.
        // locals below are the bind targets referenced by getWhereClause(filter)
        MRG_Duplicate_SVC.candidateFilter f = filter == null ? new MRG_Duplicate_SVC.candidateFilter() : filter;
        String objectType = f.objectType;
        String ruleName = f.ruleName;
        Decimal confidenceMin = f.confidenceMin;
        Decimal confidenceMax = f.confidenceMax;
        Boolean autoMerge = f.autoMerge;
        List<String> statuses = f.safeStatuses();
        String pairQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        pairQuery += MRG_Duplicate_SVC.getWhereClause(f);
        pairQuery += ' ORDER BY ConfidenceScore__c DESC NULLS LAST, KeepRecordId__c, CreatedDate DESC, Id ASC';
        pairQuery += ' LIMIT ' + limitAmt;
        if(offsetAmt != null
            && offsetAmt < 2000
            && offsetAmt > 0)
            pairQuery += ' OFFSET :offsetAmt';
        // group the page's pairs by kept record, preserving first-seen (confidence) order
        Map<String, keepGroup> groupsByKeep = new Map<String, keepGroup>();
        List<String> keepOrder = new List<String>();
        for(MergeCandidate__c c:(List<MergeCandidate__c>) Database.query(pairQuery)) {
            if(!groupsByKeep.containsKey(c.KeepRecordId__c)) {
                groupsByKeep.put(c.KeepRecordId__c, new keepGroup(c));
                keepOrder.add(c.KeepRecordId__c);
            }
            groupsByKeep.get(c.KeepRecordId__c).pairs.add(new mergeGroup(c));
        }
        List<keepGroup> result = new List<keepGroup>();
        for(String keepId:keepOrder)
            result.add(groupsByKeep.get(keepId));
        return result;
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static List<MRG_Duplicate_SVC.dupeRule> getRules(String objectType){
        return MRG_Duplicate_SVC.getMergeCandidateRules(objectType);
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String mergeRecord(String recordId){
        system.debug('merge record: '+recordId);
        String response;
        String soqlQuery  = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery+=' WHERE Id=:recordId';
        List<MergeCandidate__c> mergeCandidates = (List<MergeCandidate__c>) database.query(soqlQuery);
        if(mergeCandidates.size()>0) {
            MRG_Merge_SVC.processMergesFromBatch(mergeCandidates, mergeCandidates[0].Object__c,false);
            response = 'Records merged';
        } else {
            response = 'an error occurred';
        }
        return response;
    }

	/*******************************************************************************************************
	* @description merges the Accounts associated with a candidate's contacts (the contacts are kept)
	* instead of merging the contacts (#35)
	* @param recordId the merge candidate recordId
	* @return String response
	*/
    @AuraEnabled
    public static String mergeAccounts(String recordId){
        String soqlQuery  = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery+=' WHERE Id=:recordId';
        List<MergeCandidate__c> mergeCandidates = (List<MergeCandidate__c>) database.query(soqlQuery);
        if(mergeCandidates.isEmpty())
            return 'an error occurred';
        Id keepAccountId = MRG_AccountMerge_SVC.mergeAccounts(mergeCandidates[0]);
        return keepAccountId != null ? 'Accounts merged' : 'No accounts to merge (records share an account or have none)';
    }

	/*******************************************************************************************************
	* @description returns the records for preview
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String previewRecord(String recordId){
        String response;

        return response;
    }
	/*******************************************************************************************************
	* @description sets the merge candidate to ignore
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String removeRecord(String recordId){
        String response;
        MergeCandidate__c mc = new MergeCandidate__c(
            Id=recordId,
            NotADuplicate__c=true
        );
        try {
            update mc;
            response = 'Record set to not a duplicate';
        } catch(Exception e){
            response = e.getMessage();
        }
        return response;
    }
	/*******************************************************************************************************
	* @description merges several candidates at once (grid multi-select, #84)
	* @param recordIds the merge candidate recordIds
	* @return String response
	*/
    @AuraEnabled
    public static String mergeRecords(List<Id> recordIds){
        if(recordIds == null || recordIds.isEmpty())
            return 'No records selected';
        String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL() + ' WHERE Id IN :recordIds';
        List<MergeCandidate__c> candidates = (List<MergeCandidate__c>) Database.query(soqlQuery);
        Map<String, List<MergeCandidate__c>> byObject = new Map<String, List<MergeCandidate__c>>();
        for(MergeCandidate__c c:candidates){
            if(!byObject.containsKey(c.Object__c))
                byObject.put(c.Object__c, new List<MergeCandidate__c>());
            byObject.get(c.Object__c).add(c);
        }
        for(String objType:byObject.keySet())
            MRG_Merge_SVC.processMergesFromBatch(byObject.get(objType), objType, false);
        return candidates.size() + ' record(s) merged';
    }
	/*******************************************************************************************************
	* @description marks several candidates as not-a-duplicate at once (grid multi-select, #84)
	* @param recordIds the merge candidate recordIds
	* @return String response
	*/
    @AuraEnabled
    public static String removeRecords(List<Id> recordIds){
        if(recordIds == null || recordIds.isEmpty())
            return 'No records selected';
        List<MergeCandidate__c> updates = new List<MergeCandidate__c>();
        for(Id rid:recordIds)
            updates.add(new MergeCandidate__c(Id=rid, NotADuplicate__c=true));
        try {
            update updates;
            return updates.size() + ' record(s) set to not a duplicate';
        } catch(Exception e){
            return e.getMessage();
        }
    }
	/*******************************************************************************************************
	* @description overrides a single kept-field value for a grid group: writes the chosen value as a
	* field override onto every candidate pair that shares the kept record, preserving any other overrides
	* already stored. Mirrors the preview's manual override, keyed by kept record id at merge time.
	* @param candidateIds the merge candidate ids of the group (all pairs sharing the kept record)
	* @param field the field API name being overridden
	* @param value the chosen value (one of the non-null values across the group's records)
	* @return String response
	*/
    @AuraEnabled
    public static String setKeepFieldOverride(List<Id> candidateIds, String field, String value){
        if(candidateIds == null || candidateIds.isEmpty() || String.isBlank(field))
            return 'No override to save';
        List<MergeCandidate__c> cands = [
            SELECT Id, Object__c, Override__c, PairKey__c, KeepRecordId__c, MergeRecordId__c
            FROM MergeCandidate__c WHERE Id IN :candidateIds];
        if(cands.isEmpty())
            return 'No candidates';
        // resolve the field's SOAP type so a typed value (date/number/boolean) coerces correctly at merge
        String fieldType = null;
        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(cands[0].Object__c);
        if(sobjType != null){
            Map<String, Schema.SObjectField> fmap = sobjType.getDescribe().fields.getMap();
            if(fmap.containsKey(field.toLowerCase()))
                fieldType = fmap.get(field.toLowerCase()).getDescribe().getSOAPType().name();
        }
        for(MergeCandidate__c c:cands){
            List<MRG_MergeCandidate.fieldOverride> overrides = String.isBlank(c.Override__c)
                ? new List<MRG_MergeCandidate.fieldOverride>()
                : (List<MRG_MergeCandidate.fieldOverride>) JSON.deserialize(c.Override__c, List<MRG_MergeCandidate.fieldOverride>.class);
            Boolean found = false;
            for(MRG_MergeCandidate.fieldOverride o:overrides){
                if(o.fieldName == field){ o.fieldValue = value; o.fieldType = fieldType; found = true; break; }
            }
            if(!found){
                MRG_MergeCandidate.fieldOverride o = new MRG_MergeCandidate.fieldOverride();
                o.fieldName = field;
                o.fieldValue = value;
                o.fieldType = fieldType;
                overrides.add(o);
            }
            c.Override__c = JSON.serialize(overrides);
            // PairKey__c is required; backfill its canonical value if a legacy record is missing it so the
            // override update doesn't fail required-field validation
            if(String.isBlank(c.PairKey__c) && String.isNotBlank(c.KeepRecordId__c) && String.isNotBlank(c.MergeRecordId__c))
                c.PairKey__c = c.KeepRecordId__c + '-' + c.MergeRecordId__c;
        }
        update cands;
        return 'Keep value overridden';
    }
	/*******************************************************************************************************
	* @description merges the Accounts for several contact candidates at once (grid multi-select, #84)
	* @param recordIds the merge candidate recordIds
	* @return String response
	*/
    @AuraEnabled
    public static String mergeAccountsBulk(List<Id> recordIds){
        if(recordIds == null || recordIds.isEmpty())
            return 'No records selected';
        String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL() + ' WHERE Id IN :recordIds';
        List<MergeCandidate__c> candidates = (List<MergeCandidate__c>) Database.query(soqlQuery);
        Integer merged = 0;
        for(MergeCandidate__c c:candidates){
            if(MRG_AccountMerge_SVC.mergeAccounts(c) != null)
                merged++;
        }
        return merged + ' account merge(s) completed';
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<MergeCandidate__c> a list of merge candidates to save
	*/
    public static List<SObject> getSObjectsFromMergeGroup(String mergeGroupJSON){
        mergeGroup mergeGroup = (mergeGroup) JSON.deserialize(mergeGroupJSON, mergeGroup.class);
        List<String> recordIds = mergeGroup.recordIds;
        String objectType = mergeGroup.objectType;
        String soqlQuery = MRG_Merge_SVC.getSOQLQuery(objectType);
        soqlQuery+=' WHERE Id IN:recordIds';
        return database.query(soqlQuery);
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<MergeCandidate__c> a list of merge candidates to save
	*/
    public static List<MergeCandidate__c> getMergeCandidateFromMergeGroup(List<mergeGroup> mergeGroups){
        List<MergeCandidate__c> mergeCandidates = new List<MergeCandidate__c>();
        for(mergeGroup mergeGroup:mergeGroups){
            mergeCandidates.add(getMergeCandidateFromMergeGroup(mergeGroup));
        }
        return mergeCandidates;
    }

	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param mergeGroup the mergeGroup wrapper
	* @return  MergeCandidate__c the MergeCandidate__c object
	*/
    public static MergeCandidate__c getMergeCandidateFromMergeGroup(mergeGroup mergeGroup){
        MergeCandidate__c mergeCandidate = new MergeCandidate__c(
            KeepRecordId__c = mergeGroup.keepId,
            MergeRecordId__c = mergeGroup.mergeId,
            Object__c = mergeGroup.objectType,
            Rule__c = mergeGroup.rule,
            Status__c = mergeGroup.status,
            Merge2RecordId__c = mergeGroup.merge2Id
        );
        if(String.isNotBlank(mergeGroup.id))
            mergeCandidate.Id = mergeGroup.id;
        
        return mergeCandidate;
    }


	/*******************************************************************************************************
	* @description merge group
	*/ 
    public class keepGroup {
        @AuraEnabled
        public String keepId;
        @AuraEnabled
        public String keepName;
        @AuraEnabled
        public String objectType;
        @AuraEnabled
        public List<mergeGroup> pairs;
        @AuraEnabled
        public String keepLink {
            get { return '/' + this.keepId; }
        }
        public keepGroup(MergeCandidate__c mergeCandidate) {
            this.keepId = mergeCandidate.KeepRecordId__c;
            this.keepName = mergeCandidate.KeepName__c;
            this.objectType = mergeCandidate.Object__c;
            this.pairs = new List<mergeGroup>();
        }
    }

    public class mergeGroup {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String keepId;  
        @AuraEnabled
        public String keepName;  
        @AuraEnabled
        public String mergeId; 
        @AuraEnabled
        public String mergeName; 
        @AuraEnabled
        public String merge2Id;
        @AuraEnabled
        public String merge2Name;
        @AuraEnabled
        public String objectType;
        @AuraEnabled
        public String rule;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Boolean autoMerge;
        @AuraEnabled
        public Decimal confidenceScore;
        @AuraEnabled
        public String source;
        @AuraEnabled
        public Datetime createdDate;
        @AuraEnabled
        public Datetime lastModifiedDate;  
        @AuraEnabled
        public List<String> recordIds;
        @AuraEnabled
        public String link {
            get {
                return '/'+this.id;
            }
        }
        @AuraEnabled
        public String keepLink {
            get {
                return '/'+this.keepId;
            }
        }
        @AuraEnabled
        public String mergeLink {
            get {
                return '/'+this.mergeId;
            }
        }
        @AuraEnabled
        public String merge2Link {
            get {
                String link = null;
                if(String.isNotBlank(merge2Id)) {
                    link = '/'+this.merge2Id;
                }
                return link;
            }
        }

        public mergeGroup(MergeCandidate__c mergeCandidate){
            this.id = mergeCandidate.Id;
            this.name = mergeCandidate.name;
            this.keepId = mergeCandidate.KeepRecordId__c;
            this.keepName = mergeCandidate.KeepName__c;
            this.mergeId = mergeCandidate.MergeRecordId__c;
            this.mergeName = mergeCandidate.MergeName__c;
            this.merge2Id = mergeCandidate.Merge2RecordId__c;
            this.merge2Name = mergeCandidate.Merge2Name__c;
            this.objectType = mergeCandidate.Object__c;
            this.rule = mergeCandidate.Rule__c;
            this.status = mergeCandidate.Status__c;
            this.autoMerge = mergeCandidate.AutoMerge__c;
            this.confidenceScore = mergeCandidate.ConfidenceScore__c;
            this.source = mergeCandidate.Source__c;
            this.createdDate = mergeCandidate.CreatedDate;
            this.lastModifiedDate = mergeCandidate.LastModifiedDate;
            this.recordIds = new List<String>();
            if(String.isNotBlank(this.keepId))
                this.recordIds.add(this.keepId);
            if(String.isNotBlank(this.mergeId))
                this.recordIds.add(this.mergeId);
            if(String.isNotBlank(this.merge2Id))
                this.recordIds.add(this.merge2Id);
        }
    }

    // ---- grid helpers (#84) ----
	/*******************************************************************************************************
	* @description the set of field API names (lower-cased) hidden from the preview for an object
	*/
    private static Set<String> hiddenPreviewFields(String objectType){
        Set<String> hidden = new Set<String>();
        for(MRG_MergeSettings_CTRL.previewField pf:MRG_MergeSettings_CTRL.getAllPreviewFields(objectType)){
            if(pf.hidden && String.isNotBlank(pf.fieldName))
                hidden.add(pf.fieldName.toLowerCase());
        }
        return hidden;
    }
	/*******************************************************************************************************
	* @description resolves a field's label/type from the object's describe map (falls back to the name)
	*/
    private static gridFieldOption fieldOption(Map<String, Schema.SObjectField> fmap, String name){
        gridFieldOption o = new gridFieldOption();
        o.name = name;
        if(fmap.containsKey(name.toLowerCase())){
            Schema.DescribeFieldResult dfr = fmap.get(name.toLowerCase()).getDescribe();
            o.name = dfr.getName();
            o.label = dfr.getLabel();
            o.type = String.valueOf(dfr.getType());
        } else {
            o.label = name;
            o.type = 'STRING';
        }
        return o;
    }
	/*******************************************************************************************************
	* @description a row of display-field cells for a queried record (fields were queried, so get() is safe)
	*/
    private static gridRow buildRow(String rowType, String recordId, String candidateId, Boolean selectable, List<String> fields, SObject rec){
        gridRow row = new gridRow();
        row.rowType = rowType;
        row.recordId = recordId;
        row.candidateId = candidateId;
        row.selectable = selectable;
        row.cells = new List<gridCell>();
        for(String fld:fields){
            gridCell cell = new gridCell();
            cell.name = fld;
            cell.value = rec != null ? toStr(rec.get(fld)) : '';
            row.cells.add(cell);
        }
        return row;
    }
	/*******************************************************************************************************
	* @description the simulated result row: the kept record's value overlaid with any field the merge
	* engine changed (read from the serialized result map so unqueried fields don't throw)
	*/
    private static gridRow buildResultRow(List<String> fields, SObject keepRec, Map<String,Object> resultMap, Map<String,Object> ov){
        gridRow row = new gridRow();
        row.rowType = 'result';
        row.recordId = keepRec != null ? (String) keepRec.get('Id') : null;
        row.candidateId = null;
        row.selectable = false;
        row.cells = new List<gridCell>();
        for(String fld:fields){
            gridCell cell = new gridCell();
            cell.name = fld;
            String lf = fld.toLowerCase();
            Object val = (resultMap != null && resultMap.containsKey(lf)) ? resultMap.get(lf)
                : (keepRec != null ? keepRec.get(fld) : null);
            cell.value = toStr(val);
            // flag values that came from a manual override so the grid can highlight them
            if(ov != null && ov.containsKey(fld))
                cell.overrideValue = toStr(ov.get(fld));
            row.cells.add(cell);
        }
        return row;
    }
	/*******************************************************************************************************
	* @description an SObject as a lower-cased-key value map (only populated/queried fields are present)
	*/
    private static Map<String,Object> lowerKeyed(SObject rec){
        Map<String,Object> out = new Map<String,Object>();
        Map<String,Object> m = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(rec));
        for(String k:m.keySet())
            out.put(k.toLowerCase(), m.get(k));
        return out;
    }
    private static String toStr(Object val){
        return val == null ? '' : String.valueOf(val);
    }

    // ---- grid wrappers (#84) ----
    public class gridFieldOptions {
        @AuraEnabled public List<gridFieldOption> leadFields;
        @AuraEnabled public List<gridFieldOption> fields;
        @AuraEnabled public List<gridFieldOption> trailFields;
    }
    public class gridFieldOption implements Comparable {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String displayLabel;
        @AuraEnabled public Boolean selected;
        public Integer compareTo(Object o){
            gridFieldOption other = (gridFieldOption) o;
            String a = this.label == null ? '' : this.label.toLowerCase();
            String b = other.label == null ? '' : other.label.toLowerCase();
            return a.compareTo(b);
        }
    }
    public class gridResponse {
        @AuraEnabled public List<gridFieldOption> columns;
        @AuraEnabled public List<gridGroup> groups;
    }
    public class gridGroup {
        @AuraEnabled public String keepId;
        @AuraEnabled public String keepName;
        @AuraEnabled public String objectType;
        @AuraEnabled public List<gridRow> rows;
    }
    public class gridRow {
        @AuraEnabled public String rowType;
        @AuraEnabled public String recordId;
        @AuraEnabled public String candidateId;
        @AuraEnabled public Boolean selectable;
        @AuraEnabled public List<gridCell> cells;
    }
    public class gridCell {
        @AuraEnabled public String name;
        @AuraEnabled public String value;
        @AuraEnabled public String overrideValue;
    }
}
