/**
* @author tj@tjgriffin.com
* @group Merge
* @description model + group-wide evaluation for a "Complex" field-preservation rule (#33).
*
* A complex rule preserves a field's value from the record in a merge group that (a) matches the
* rule's conditions (reusing MRG_KeepRecordRule.condition + MRG_FilterLogic), and (b) wins a
* tie-break ordering (a field, ascending or descending) when more than one record matches.
*
* Unlike the pairwise Oldest/Newest/Largest/Smallest rules, this is evaluated once over the whole
* group of records (kept + merged) in a separate pass.
*/
public with sharing class MRG_ComplexPreserveRule {

	@auraEnabled public String fieldName;          // the field whose value is preserved
	@auraEnabled public String filterLogic;        // report-style logic over the conditions
	@auraEnabled public List<MRG_KeepRecordRule.condition> conditions;
	@auraEnabled public String tieBreakField;      // field used to rank matching records (secondary)
	@auraEnabled public String tieBreakDirection;  // 'ASC' or 'DESC' (default DESC) for the field
	@auraEnabled public String tieBreakRule;       // primary tie-break: a standard preservation rule

	public MRG_ComplexPreserveRule() {
		this.conditions = new List<MRG_KeepRecordRule.condition>();
		this.tieBreakDirection = 'DESC';
	}

	/*******************************************************************************************************
	* @description the fields this rule reads (its own field, condition fields, tie-break field) so the
	* caller can ensure they are queried
	* @return Set<String> field api names
	*/
	public Set<String> referencedFields() {
		Set<String> fields = new Set<String>();
		if(String.isNotBlank(fieldName))
			fields.add(fieldName);
		if(String.isNotBlank(tieBreakField))
			fields.add(tieBreakField);
		if(conditions != null) {
			for(MRG_KeepRecordRule.condition c:conditions) {
				if(String.isNotBlank(c.fieldName))
					fields.add(c.fieldName);
			}
		}
		return fields;
	}

	/*******************************************************************************************************
	* @description whether a record matches this rule's conditions under its filter logic
	* @param record the record to test
	* @return Boolean
	*/
	public Boolean matches(SObject record) {
		if(conditions == null || conditions.isEmpty())
			return false;
		Map<Integer, Boolean> results = new Map<Integer, Boolean>();
		Integer i = 1;
		for(MRG_KeepRecordRule.condition c:conditions) {
			results.put(i, c.evaluate(record));
			i++;
		}
		return MRG_FilterLogic.evaluate(filterLogic, results);
	}

	/*******************************************************************************************************
	* @description selects the winning record across a group: the matching record ranked first by the
	* tie-break ordering. Returns null when no record matches the conditions.
	* @param records the full merge group (kept + merged)
	* @return SObject the winning record, or null
	*/
	public SObject selectWinner(List<SObject> records) {
		if(records == null || records.isEmpty())
			return null;
		List<SObject> matches = new List<SObject>();
		for(SObject record:records) {
			if(matches(record))
				matches.add(record);
		}
		if(matches.isEmpty())
			return null;
		if(matches.size() == 1)
			return matches[0];
		// rank by the primary tie-break rule (when set), then by the secondary tie-break field+direction
		Boolean hasPrimary = String.isNotBlank(tieBreakRule);
		Boolean primaryDesc = primaryDescending();
		Boolean primaryByLength = isLengthRule();
		Boolean secondaryDesc = tieBreakDirection == null || tieBreakDirection.equalsIgnoreCase('DESC');
		List<rankedRecord> ranked = new List<rankedRecord>();
		for(SObject record:matches) {
			Object primaryVal = hasPrimary ? primaryRankValue(record) : null;
			Object secondaryVal = String.isNotBlank(tieBreakField) ? record.get(tieBreakField) : null;
			ranked.add(new rankedRecord(record, hasPrimary, primaryVal, primaryDesc, primaryByLength, secondaryVal, secondaryDesc));
		}
		ranked.sort();
		return ranked[0].record;
	}

	/*******************************************************************************************************
	* @description the value the primary rule ranks on: CreatedDate for Oldest/Newest, otherwise the
	* tie-break field value (Largest/Smallest compare value, Longest/Shortest compare text length)
	*/
	private Object primaryRankValue(SObject record) {
		String rule = tieBreakRule == null ? '' : tieBreakRule.toLowerCase();
		if(rule == 'newest' || rule == 'oldest')
			return record.get('CreatedDate');
		return String.isNotBlank(tieBreakField) ? record.get(tieBreakField) : null;
	}
	private Boolean primaryDescending() {
		String rule = tieBreakRule == null ? '' : tieBreakRule.toLowerCase();
		return rule == 'newest' || rule == 'largest' || rule == 'longest';
	}
	private Boolean isLengthRule() {
		String rule = tieBreakRule == null ? '' : tieBreakRule.toLowerCase();
		return rule == 'longest' || rule == 'shortest';
	}

	/*******************************************************************************************************
	* @description the value to preserve for this rule across a group: the winning record's field value.
	* Returns null when no record matches (caller leaves the field unchanged).
	* @param records the full merge group
	* @return Object the value to write onto the kept record, or null
	*/
	public Object winningValue(List<SObject> records) {
		SObject winner = selectWinner(records);
		return winner == null ? null : winner.get(fieldName);
	}

	/*******************************************************************************************************
	* @description a record paired with its tie-break value, comparable so the winner sorts first
	*/
	private class rankedRecord implements Comparable {
		public SObject record;
		Boolean hasPrimary;
		Object primaryVal;
		Boolean primaryDesc;
		Boolean primaryByLength;
		Object secondaryVal;
		Boolean secondaryDesc;

		public rankedRecord(SObject record, Boolean hasPrimary, Object primaryVal, Boolean primaryDesc, Boolean primaryByLength, Object secondaryVal, Boolean secondaryDesc) {
			this.record = record;
			this.hasPrimary = hasPrimary;
			this.primaryVal = primaryVal;
			this.primaryDesc = primaryDesc;
			this.primaryByLength = primaryByLength;
			this.secondaryVal = secondaryVal;
			this.secondaryDesc = secondaryDesc;
		}

		public Integer compareTo(Object compareTo) {
			rankedRecord other = (rankedRecord) compareTo;
			if(hasPrimary) {
				Integer p = directedCompare(this.primaryVal, other.primaryVal, this.primaryDesc, this.primaryByLength);
				if(p != 0)
					return p;
			}
			return directedCompare(this.secondaryVal, other.secondaryVal, this.secondaryDesc, false);
		}
	}

	/*******************************************************************************************************
	* @description directional compare with nulls always last; by text length when byLength, else by value
	*/
	private static Integer directedCompare(Object a, Object b, Boolean descending, Boolean byLength) {
		if(a == null && b == null) return 0;
		if(a == null) return 1;   // nulls rank last regardless of direction
		if(b == null) return -1;
		Integer raw = byLength ? compareLengths(a, b) : compareValues(a, b);
		return descending ? -raw : raw;
	}
	private static Integer compareLengths(Object a, Object b) {
		Integer la = String.valueOf(a).length();
		Integer lb = String.valueOf(b).length();
		return la == lb ? 0 : (la > lb ? 1 : -1);
	}
	// raw type-aware compare of two non-null values: +1 if a>b, -1 if a<b, 0 if equal
	private static Integer compareValues(Object a, Object b) {
		String type = MRG_Merge_SVC.getObjectType(a);
		switch on type {
			when 'Date' {
				Date da = (Date) a, db = (Date) b;
				return da == db ? 0 : (da > db ? 1 : -1);
			}
			when 'Datetime' {
				Datetime da = (Datetime) a, db = (Datetime) b;
				return da == db ? 0 : (da > db ? 1 : -1);
			}
			when 'Integer', 'Long', 'Decimal', 'Double' {
				Decimal da = Decimal.valueOf(String.valueOf(a)), db = Decimal.valueOf(String.valueOf(b));
				return da == db ? 0 : (da > db ? 1 : -1);
			}
			when else {
				String sa = String.valueOf(a), sb = String.valueOf(b);
				return sa == sb ? 0 : (sa > sb ? 1 : -1);
			}
		}
	}
}
