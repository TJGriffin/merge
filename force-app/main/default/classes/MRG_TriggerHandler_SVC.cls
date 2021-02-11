global with sharing class MRG_TriggerHandler_SVC {
	
	/*******************************************************************************************************
	* @description run the trigger
	* @param isInsert if the action is an insert
	* @param isUpdate if the action is an update
	* @param isDelete if the action is a delete
	* @param isUndelete if the action is an undelete
	* @param newRecords records from trigger.new
	* @param oldRecords records from trigger.old
	* @param objectType the object type that the trigger is running on
	*/ 	
	global static void runTrigger(Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete, List<SObject> newRecords, List<SObject> oldRecords, String objectType) {
		// TODO: handle merges
		//  currently there isn't an endpoint for merges on the EA side
		if(IsDelete || isUndelete)
            return;
        
        switch on objectType {
            when 'MergeCandidate__c' {
                MRG_MergeCandidate_TRG.runTrigger(isBefore, isAfter, isInsert,isUpdate,isDelete,isUndelete,newRecords,oldRecords);
            }
        }
    }
}
