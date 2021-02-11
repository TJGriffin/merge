public with sharing class MRG_MergeCandidate_TRG {
	
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
	public static void runTrigger(Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete, List<SObject> newRecords, List<SObject> oldRecords) {
		// TODO: handle merges
		//  currently there isn't an endpoint for merges on the EA side
		if(IsDelete || isUndelete)
            return;
        
        if(isUpdate){
            if(isBefore){
                Integer i=0;
                for(SObject obj:newRecords){
                    if((String)obj.get('Status__c') != null
                        && obj.get('Status__c') == 'Processed'
                        && obj.get('MergeProcessDate__c') == null){
                            obj.put('MergeProcessDate__c',Date.Today());
                        }
                    i++;
                }
            }

        }
    }
}
