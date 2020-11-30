/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger ContactMerge on Contact (after delete) {
	if(CON_Merge_SVC.getTriggerDisabled('Contact'))
		return;
	if(CON_Duplicate_SVC.getTriggerDisabled())
		return;
	if(trigger.isAfter) {
		if(System.isBatch() 
			|| System.isQueueable()) {
				List<SObject> mergeRecords = new List<SOBJECT>((List<SObject>) JSON.deserialize(JSON.serialize(trigger.old),List<SObject>.class));
				CON_Merge_SVC.createMergeRecords((List<SObject>)mergeRecords,'Contact');
		} else {
			String deletedContactJSON = JSON.serialize(Trigger.old);
			system.enqueueJob(new CON_Merge_QUEUE(deletedContactJSON,'Contact'));
		}
	}
}