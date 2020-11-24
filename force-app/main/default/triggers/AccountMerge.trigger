/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger AccountMerge on Account (after delete) {
	if(CON_Merge_SVC.getTriggerDisabled('Account'))
		return;
	if(trigger.isAfter) {
		String deletedAccountJSON = JSON.serialize(Trigger.old);
		system.enqueueJob(new CON_Merge_QUEUE(deletedAccountJSON,'Account'));
	}
}