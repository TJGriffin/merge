/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description batch class to scan for duplicates
*/
public with sharing class MRG_DuplicateScan_BATCH implements Database.Batchable<sObject>, Schedulable, Database.stateful {
	
	/*******************************************************************************************************
	* @description set of objects to scan
	*/  
    @testvisible private Set<String> objects;

	/*******************************************************************************************************
	* @description set of objects to scan
	*/  
    @testvisible private String objectType;

	/*******************************************************************************************************
	* @description constructor
	*/
    public MRG_DuplicateScan_Batch() {
        this.objects = new Set<String>{'Account','Contact'};
    }

	/*******************************************************************************************************
	* @description constructor
	*/
    public MRG_DuplicateScan_Batch(Set<String> objects) {
        this.objects = objects;
    }

	/*******************************************************************************************************
	* @description batch start method
	* @param BC batchable context
	* @return Querylocator the scope of the batch
	*/  	 
	public Database.QueryLocator start(Database.BatchableContext BC) {
        List<String> objectList = new List<String>();
        objectList.addAll(objects);
        objectType = objectList[0];
        String soqlQuery = MRG_Duplicate_SVC.getScanSOQLQuery(objectType);
        return Database.getQueryLocator(SOQLQuery);	

    }
	/*******************************************************************************************************
	* @description batch execute method
	* @param BC batchable context
	* @param scope list of records to process
	*/ 
	public void execute(Database.BatchableContext BC, List<sObject> scope) {
        Map<Id, SObject> recordMap = new Map<Id, SObject>(scope);
        List<MergeCandidate__c> mergeCandidates = MRG_Duplicate_SVC.processRecords(recordMap,objectType);
        if(mergeCandidates.size()>0)
            upsert mergeCandidates KeepRecordId__c;
    }
	 /*******************************************************************************************************
	* @description batch finish method, writes out logs and kicks off next process in the chain
	* @param BC batchable context
	*/ 
	public void finish(Database.BatchableContext BC) {
		if(objects.size()>1){
            objects.remove(objectType);
            Database.executeBatch(new MRG_DuplicateScan_BATCH(objects),50);
        }

	}
	/*******************************************************************************************************
	* @description Schedulable execute method
	* @param SC Schedulable Context
	*/
	public void execute(SchedulableContext SC) {
		database.executeBatch(this, 50);
	}

}
