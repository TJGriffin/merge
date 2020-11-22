/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger ContactMerge on Contact (after delete) {
	if(trigger.isAfter) {
		String deletedContactJSON = JSON.serialize(Trigger.old);
		system.enqueueJob(new CON_Merge_QUEUE(deletedContactJSON));
	}
}