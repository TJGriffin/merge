/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger AccountMerge on Account (after delete) {
	if(MRG_Merge_SVC.getTriggerDisabled('Account'))
		return;
	if(MRG_Duplicate_SVC.getTriggerDisabled())
		return;
	if(trigger.isAfter) {
		List<SObject> mergeRecords = new List<SOBJECT>((List<SObject>) JSON.deserialize(JSON.serialize(trigger.old),List<SObject>.class));
		String deletedAccountJSON = JSON.serialize(Trigger.old);
		if(System.isBatch() 
			|| System.isQueueable()) {
				MRG_Merge_SVC.createMergeRecords((List<SObject>)mergeRecords,'Account');
		} else {
			system.enqueueJob(new MRG_Merge_QUEUE(deletedAccountJSON,'Account'));

		}
	}
}