/**
* @author tj@tjgriffin.com
* @group Merge
* @description Context passed to an MRG_FieldKeepRule. Carries the target field, the surviving record
* with every value resolved so far (after preserve / related / complex / manual override), the
* surviving record's pre-merge values, and the losing (merged) records, so custom logic can make
* cross-field and cross-record decisions.
*/
global class MRG_FieldKeepContext {
	/*** @description the SObject api name being merged */
	global String objectType;
	/*** @description the field the resolver is deciding */
	global String fieldName;
	/*** @description the surviving record with values resolved so far (mutable; only fieldName is read back) */
	global SObject keepRecord;
	/*** @description the surviving record's pre-merge values */
	global SObject keepOriginal;
	/*** @description the losing records (original values) */
	global List<SObject> mergeRecords;
	/*** @description the value the built-in rules chose for fieldName */
	global Object currentValue;

	/*******************************************************************************************************
	* @description constructor
	*/
	global MRG_FieldKeepContext(String objectType, String fieldName, SObject keepRecord, SObject keepOriginal, List<SObject> mergeRecords) {
		this.objectType = objectType;
		this.fieldName = fieldName;
		this.keepRecord = keepRecord;
		this.keepOriginal = keepOriginal;
		this.mergeRecords = mergeRecords == null ? new List<SObject>() : mergeRecords;
		this.currentValue = keepRecord != null ? keepRecord.get(fieldName) : null;
	}
}
