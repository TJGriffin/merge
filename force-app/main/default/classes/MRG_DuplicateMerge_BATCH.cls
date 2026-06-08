/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description batch class to scan for duplicates
*/
public with sharing class MRG_DuplicateMerge_BATCH implements Database.Batchable<sObject>, Schedulable, Database.stateful {
	/*******************************************************************************************************
	* @description the Account trigger disabled state to restore when the batch chain finishes
	*/
    @testvisible private Boolean accountTriggerDisabled;
	/*******************************************************************************************************
	* @description the Contact trigger disabled state to restore when the batch chain finishes
	*/
    @testvisible private Boolean contactTriggerDisabled;
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
    public MRG_DuplicateMerge_BATCH() {
        this.objects = new Set<String>{'Account','Contact'};
    }

	/*******************************************************************************************************
	* @description constructor
	*/
    public MRG_DuplicateMerge_BATCH(Set<String> objects) {
        this.objects = objects;
    }

	/*******************************************************************************************************
	* @description constructor used to carry the original trigger-disabled state forward through the
	* batch chain so the last batch in the chain restores the true pre-batch values
	*/
    public MRG_DuplicateMerge_BATCH(Set<String> objects, Boolean accountTriggerDisabled, Boolean contactTriggerDisabled) {
        this.objects = objects;
        this.accountTriggerDisabled = accountTriggerDisabled;
        this.contactTriggerDisabled = contactTriggerDisabled;
    }

	/*******************************************************************************************************
	* @description batch start method
	* @param BC batchable context
	* @return Querylocator the scope of the batch
	*/  	 
	public Database.QueryLocator start(Database.BatchableContext BC) {
        MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
        // only capture the original state on the first batch in the chain; later batches in the
        // chain receive the original values via the constructor so they aren't overwritten with
        // the already-disabled state this batch set.
        if(accountTriggerDisabled == null && settings != null)
            accountTriggerDisabled = settings.DisableAccountTrigger__c;
        if(contactTriggerDisabled == null && settings != null)
            contactTriggerDisabled = settings.DisableContactTrigger__c;
        settings.DisableAccountTrigger__c = true;
        settings.DisableContactTrigger__c = true;
        upsert settings;
        List<String> objectList = new List<String>();
        objectList.addAll(objects);
        objectType = objectList[0];
		String soqlQuery  = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery += ' WHERE Status__c=\'New\' AND Object__c =:objectType AND AutoMerge__c = true AND NotADuplicate__c = false';
        return Database.getQueryLocator(SOQLQuery);	
    }
	/*******************************************************************************************************
	* @description batch execute method
	* @param BC batchable context
	* @param scope list of records to process
	*/ 
	public void execute(Database.BatchableContext BC, List<sObject> scope) {
        MRG_Merge_SVC.processMergesFromBatch((List<MergeCandidate__c>) scope, objectType);
    }
	 /*******************************************************************************************************
	* @description batch finish method, writes out logs and kicks off next process in the chain
	* @param BC batchable context
	*/ 
	public void finish(Database.BatchableContext BC) {
		if(objects.size()>1){
            objects.remove(objectType);
            Database.executeBatch(new MRG_DuplicateMerge_BATCH(objects, accountTriggerDisabled, contactTriggerDisabled),1);
        } else {
            // last batch in the chain: restore the trigger-disabled state captured before the run
            MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
            if(settings != null) {
                settings.DisableAccountTrigger__c = accountTriggerDisabled == null ? false : accountTriggerDisabled;
                settings.DisableContactTrigger__c = contactTriggerDisabled == null ? false : contactTriggerDisabled;
                upsert settings;
            }
        }
    }
	/*******************************************************************************************************
	* @description Schedulable execute method
	* @param SC Schedulable Context
	*/
	public void execute(SchedulableContext SC) {
		database.executeBatch(this,1);
	}

}
