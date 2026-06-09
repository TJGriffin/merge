/**
* @author tj@tjgriffin.com
* @group Merge
* @description model + evaluation for a single keep-record rule. A rule is an ordered set of
* conditions combined by a report-style filter logic string (see MRG_FilterLogic). A record
* "matches" a rule when its field values satisfy the rule's conditions under that logic.
*
* Stateless: evaluation reads only the supplied SObject and the rule's own definition.
*/
public with sharing class MRG_KeepRecordRule implements Comparable {

	@auraEnabled public String id;
	@auraEnabled public String label;
	@auraEnabled public String objectName;
	@auraEnabled public Integer order;
	@auraEnabled public String filterLogic;
	@auraEnabled public List<condition> conditions;

	public MRG_KeepRecordRule() {
		this.conditions = new List<condition>();
		this.order = 0;
	}

	/*******************************************************************************************************
	* @description sorts rules by their evaluation order (ascending)
	*/
	public Integer compareTo(Object compareTo) {
		MRG_KeepRecordRule other = (MRG_KeepRecordRule) compareTo;
		Integer a = this.order == null ? 0 : this.order;
		Integer b = other.order == null ? 0 : other.order;
		return a == b ? 0 : (a > b ? 1 : -1);
	}

	/*******************************************************************************************************
	* @description evaluates whether a record matches this rule
	* @param record the SObject to test (must have the condition fields populated)
	* @return Boolean true when the record satisfies the rule's conditions under its filter logic
	*/
	public Boolean matches(SObject record) {
		if(conditions == null || conditions.isEmpty())
			return false;
		Map<Integer, Boolean> results = new Map<Integer, Boolean>();
		Integer i = 1;
		for(condition c:conditions) {
			results.put(i, c.evaluate(record));
			i++;
		}
		return MRG_FilterLogic.evaluate(filterLogic, results);
	}

	/*******************************************************************************************************
	* @description the set of field api names referenced by this rule's conditions (for SOQL building)
	* @return Set<String> field api names
	*/
	public Set<String> referencedFields() {
		Set<String> fields = new Set<String>();
		if(conditions != null) {
			for(condition c:conditions) {
				if(String.isNotBlank(c.fieldName))
					fields.add(c.fieldName);
			}
		}
		return fields;
	}

	/*******************************************************************************************************
	* @description a single condition: a field, an operator, and a comparison value
	*/
	public class condition {
		@auraEnabled public String fieldName;
		@auraEnabled public String operator;   // equals, notEquals, lessThan, lessOrEqual, greaterThan, greaterOrEqual, contains, startsWith, endsWith
		@auraEnabled public String value;      // raw string value; typed via the record's field type

		public condition() {}

		public condition(String fieldName, String operator, String value) {
			this.fieldName = fieldName;
			this.operator = operator;
			this.value = value;
		}

		/*******************************************************************************************************
		* @description evaluates this condition against a record's field value
		* @param record the SObject under test
		* @return Boolean the condition result
		*/
		public Boolean evaluate(SObject record) {
			Object fieldVal = record.get(fieldName);
			String type = MRG_Merge_SVC.getObjectType(fieldVal);
			switch on operator {
				when 'equals' {
					return compareEquals(fieldVal, type);
				}
				when 'notEquals' {
					return !compareEquals(fieldVal, type);
				}
				when 'contains' {
					return fieldVal != null && value != null && String.valueOf(fieldVal).contains(value);
				}
				when 'startsWith' {
					return fieldVal != null && value != null && String.valueOf(fieldVal).startsWith(value);
				}
				when 'endsWith' {
					return fieldVal != null && value != null && String.valueOf(fieldVal).endsWith(value);
				}
				when 'lessThan', 'lessOrEqual', 'greaterThan', 'greaterOrEqual' {
					return compareOrdered(fieldVal, type);
				}
				when else {
					return false;
				}
			}
		}

		/*******************************************************************************************************
		* @description equality comparison normalized to string, with explicit null handling
		*/
		private Boolean compareEquals(Object fieldVal, String type) {
			if(fieldVal == null)
				return String.isBlank(value);
			if(type == 'Boolean')
				return ((Boolean) fieldVal) == Boolean.valueOf(value);
			return String.valueOf(fieldVal) == value;
		}

		/*******************************************************************************************************
		* @description ordered (<, <=, >, >=) comparison, typed by the field value. A null field value or
		* an unparseable comparison value yields false.
		*/
		private Boolean compareOrdered(Object fieldVal, String type) {
			if(fieldVal == null || String.isBlank(value))
				return false;
			Integer cmp;
			try {
				switch on type {
					when 'Date' {
						cmp = ((Date) fieldVal) < Date.valueOf(value) ? -1 : (((Date) fieldVal) > Date.valueOf(value) ? 1 : 0);
					}
					when 'Datetime' {
						Datetime dv = Datetime.valueOf(value);
						cmp = ((Datetime) fieldVal) < dv ? -1 : (((Datetime) fieldVal) > dv ? 1 : 0);
					}
					when 'Integer', 'Long', 'Decimal', 'Double' {
						Decimal fv = Decimal.valueOf(String.valueOf(fieldVal));
						Decimal cv = Decimal.valueOf(value);
						cmp = fv < cv ? -1 : (fv > cv ? 1 : 0);
					}
					when else {
						String fv = String.valueOf(fieldVal);
						cmp = fv < value ? -1 : (fv > value ? 1 : 0);
					}
				}
			} catch(Exception e) {
				return false;
			}
			switch on operator {
				when 'lessThan' { return cmp < 0; }
				when 'lessOrEqual' { return cmp <= 0; }
				when 'greaterThan' { return cmp > 0; }
				when 'greaterOrEqual' { return cmp >= 0; }
				when else { return false; }
			}
		}
	}

	/*******************************************************************************************************
	* @description from an ordered list of rules and a set of candidate records, returns the Id of the
	* record to keep. Rules are evaluated in order; the first rule matched by exactly one record selects
	* that record. Rules matched by zero or multiple records are skipped. Returns null when no rule yields
	* a unique match (the caller falls back to its default keep selection).
	* @param rules the ordered keep-record rules (already filtered to the object)
	* @param records the candidate records (with condition fields populated)
	* @return Id the keep record id, or null when no rule produced a unique match
	*/
	public static Id selectKeepId(List<MRG_KeepRecordRule> rules, List<SObject> records) {
		if(rules == null || rules.isEmpty() || records == null || records.isEmpty())
			return null;
		List<MRG_KeepRecordRule> ordered = new List<MRG_KeepRecordRule>(rules);
		ordered.sort();
		for(MRG_KeepRecordRule rule:ordered) {
			List<Id> matched = new List<Id>();
			for(SObject record:records) {
				if(rule.matches(record))
					matched.add((Id) record.get('Id'));
			}
			if(matched.size() == 1)
				return matched[0];
		}
		return null;
	}
}
