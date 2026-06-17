/**
* @author tj@tjgriffin.com
* @group Merge
* @description Example MRG_FieldKeepRule: keep the longest non-blank text value across the surviving
* and losing records. Ships as a reference implementation; register it on a field by setting the
* field's Preservation Rule to "Apex Defined" with ApexClass__c = MRG_SampleFieldKeepRule.
*/
global class MRG_SampleFieldKeepRule implements MRG_FieldKeepRule {
	global Object resolveValue(MRG_FieldKeepContext context) {
		Object best = context.currentValue;
		Integer bestLen = best == null ? -1 : String.valueOf(best).length();
		for(SObject record:context.mergeRecords) {
			Object value = record.get(context.fieldName);
			Integer len = value == null ? -1 : String.valueOf(value).length();
			if(len > bestLen) {
				best = value;
				bestLen = len;
			}
		}
		return best;
	}
}
