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
	@auraEnabled public String tieBreakField;      // field used to rank matching records
	@auraEnabled public String tieBreakDirection;  // 'ASC' or 'DESC' (default DESC)

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
		// rank the matches by the tie-break field; default to created order when none is set
		List<rankedRecord> ranked = new List<rankedRecord>();
		Boolean descending = tieBreakDirection == null || tieBreakDirection.equalsIgnoreCase('DESC');
		for(SObject record:matches) {
			Object val = String.isNotBlank(tieBreakField) ? record.get(tieBreakField) : null;
			ranked.add(new rankedRecord(record, val, descending));
		}
		ranked.sort();
		return ranked[0].record;
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
		Object value;
		Boolean descending;

		public rankedRecord(SObject record, Object value, Boolean descending) {
			this.record = record;
			this.value = value;
			this.descending = descending;
		}

		public Integer compareTo(Object compareTo) {
			rankedRecord other = (rankedRecord) compareTo;
			Integer cmp = compareValues(this.value, other.value);
			return descending ? -cmp : cmp;
		}

		// nulls sort last (so a present value wins regardless of direction-flip); otherwise compare by
		// the runtime type, falling back to string comparison
		private Integer compareValues(Object a, Object b) {
			if(a == null && b == null) return 0;
			if(a == null) return descending ? -1 : 1;   // a (null) should rank after b
			if(b == null) return descending ? 1 : -1;   // b (null) should rank after a
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
}
