public with sharing class MRG_MergeCandidate_BATCH implements Database.Batchable<sObject>, Schedulable {
	/*******************************************************************************************************
	* @description batch start method
	* @param BC batchable context
	* @return Querylocator the scope of the batch
	*/  	 
	public Database.QueryLocator start(Database.BatchableContext BC) {
        String SOQLQuery = MRG_MergeCandidate_SVC.getBatchSoql();
        return Database.getQueryLocator(SOQLQuery);	
    }
	/*******************************************************************************************************
	* @description batch execute method
	* @param BC batchable context
	* @param scope list of records to process
	*/ 
	public void execute(Database.BatchableContext BC, List<sObject> scope) {
        MRG_MergeCandidate_SVC.processMergeCandidatesFromBatch((List<MergeCandidate__c>)scope);
    }
    /*******************************************************************************************************
   * @description batch finish method, writes out logs and kicks off next process in the chain
   * @param BC batchable context
   */ 
   public void finish(Database.BatchableContext BC) {

   }
   /*******************************************************************************************************
   * @description Schedulable execute method
   * @param SC Schedulable Context
   */
   public void execute(SchedulableContext SC) {
       database.executeBatch(this,100);
   }
}