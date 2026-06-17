/**
* @author tj@tjgriffin.com
* @group Merge
* @description Extension point for custom field keep-value decisions during a merge. Implement this
* interface in your own Apex, then register it per field by setting that field's Merge Field Setting
* Preservation Rule to "Apex Defined" and naming the implementing class in ApexClass__c.
*
* The resolver runs AFTER all built-in rules (preserve / related / complex / manual override) have
* run, so it sees the value those rules chose plus the full record context, and returns the final
* value to keep. Because the merge preview uses the same engine, the resolver's decision is reflected
* in the preview before the merge is committed.
*/
global interface MRG_FieldKeepRule {
	/*******************************************************************************************************
	* @description decide the value to keep for context.fieldName on the surviving record
	* @param context the decision context (target field, surviving record so far, original surviving
	*        record, and the losing records)
	* @return Object the value to keep; return context.currentValue to leave the rule-decided value as-is
	*/
	Object resolveValue(MRG_FieldKeepContext context);
}
