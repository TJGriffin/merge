/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description trigger on contact delete
*/
trigger ContactMerge on Contact (after delete) {
	if(trigger.isAfter) {
		CON_Merge_SVC.createMergeRecords(Trigger.old);
	}
}