/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger ContactMerge on Contact (after delete) {
	if(MRG_Merge_SVC.getTriggerDisabled('Contact'))
		return;
	if(MRG_Duplicate_SVC.getTriggerDisabled())
		return;
	if(trigger.isAfter) {
		List<SObject> mergeRecords = new List<SOBJECT>((List<SObject>) JSON.deserialize(JSON.serialize(trigger.old),List<SObject>.class));
		String deletedContactJSON = JSON.serialize(Trigger.old);
		if(System.isBatch() 
			|| System.isQueueable()) {
				MRG_Merge_SVC.createMergeRecords((List<SObject>)mergeRecords,'Contact');
		} else {
			system.enqueueJob(new MRG_Merge_QUEUE(deletedContactJSON,'Contact'));
		}
	}
}