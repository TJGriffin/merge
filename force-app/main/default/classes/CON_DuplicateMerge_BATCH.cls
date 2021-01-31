/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description batch class to scan for duplicates
*/
public with sharing class CON_DuplicateMerge_BATCH implements Database.Batchable<sObject>, Schedulable, Database.stateful {
	/*******************************************************************************************************
	* @description set of objects to scan
	*/  
    private static Boolean accountTriggerDisabled;	
	/*******************************************************************************************************
	* @description set of objects to scan
	*/  
    private static Boolean contactTriggerDisabled;	
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
    public CON_DuplicateMerge_BATCH() {
        this.objects = new Set<String>{'Account','Contact'};
    }

	/*******************************************************************************************************
	* @description constructor
	*/
    public CON_DuplicateMerge_BATCH(Set<String> objects) {
        this.objects = objects;
    }

	/*******************************************************************************************************
	* @description batch start method
	* @param BC batchable context
	* @return Querylocator the scope of the batch
	*/  	 
	public Database.QueryLocator start(Database.BatchableContext BC) {
        MergeControlSettings__c settings = CON_Merge_SVC.getSettings();
        if(settings!=null) {
            accountTriggerDisabled = settings.DisableAccountTrigger__c;
            contactTriggerDisabled = settings.DisableContactTrigger__c;
        }
        settings.DisableAccountTrigger__c = true;
        settings.DisableContactTrigger__c = true;
        upsert settings;
        List<String> objectList = new List<String>();
        objectList.addAll(objects);
        objectType = objectList[0];
		String soqlQuery  = CON_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery += ' WHERE Status__c=\'New\' AND Object__c =:objectType AND AutoMerge__c = true';
        return Database.getQueryLocator(SOQLQuery);	
    }
	/*******************************************************************************************************
	* @description batch execute method
	* @param BC batchable context
	* @param scope list of records to process
	*/ 
	public void execute(Database.BatchableContext BC, List<sObject> scope) {
        CON_Merge_SVC.processMergesFromBatch((List<MergeCandidate__c>) scope, objectType);
    }
	 /*******************************************************************************************************
	* @description batch finish method, writes out logs and kicks off next process in the chain
	* @param BC batchable context
	*/ 
	public void finish(Database.BatchableContext BC) {
		if(objects.size()>1){
            objects.remove(objectType);
            Database.executeBatch(new CON_DuplicateMerge_BATCH(objects),50);
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
