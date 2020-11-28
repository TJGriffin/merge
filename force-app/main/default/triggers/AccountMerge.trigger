/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger AccountMerge on Account (after delete) {
	if(CON_Merge_SVC.getTriggerDisabled('Account'))
		return;
	if(CON_Duplicate_SVC.getTriggerDisabled())
		return;
	if(trigger.isAfter) {
		if(System.isBatch() 
			|| System.isQueueable()) {
				List<SObject> mergeRecords = new List<SOBJECT>((List<SObject>) JSON.deserialize(JSON.serialize(trigger.old),List<SObject>.class));
				CON_Merge_SVC.createMergeRecords((List<SObject>)mergeRecords,'Account');
		} else {
			String deletedAccountJSON = JSON.serialize(Trigger.old);
			system.enqueueJob(new CON_Merge_QUEUE(deletedAccountJSON,'Account'));

		}
	}
}