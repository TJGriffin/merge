/**
* @author tj@tjgriffin.com
* @group Merge
* @description model + evaluation for a standalone Fallback rule (#34).
*
* A fallback rule routes value(s) from a single winning record in a merge group into different
* target field(s) on the kept record, only where the target field is currently empty. It fires
* independently of track/preserve rules (it may apply to a field that has neither).
*
* Winner selection is either:
*   - simple: by record age (Oldest / Newest), or
*   - complex: conditions (MRG_KeepRecordRule.condition) + filter logic + tie-break ordering,
*     reusing the #33 group-wide selection.
*
* All source values for one rule come from the SAME winning record, so a set of related fields
* (e.g. a fallback email plus its subscription-preference fields) stay consistent.
*/
public with sharing class MRG_FallbackRule {

	@auraEnabled public String id;
	@auraEnabled public String label;
	@auraEnabled public String objectName;
	@auraEnabled public String selectionType;   // 'simple' | 'complex'
	@auraEnabled public String rule;             // simple selection: 'Oldest' | 'Newest'
	@auraEnabled public String filterLogic;      // complex selection
	@auraEnabled public List<MRG_KeepRecordRule.condition> conditions; // complex selection
	@auraEnabled public String tieBreakField;    // complex selection
	@auraEnabled public String tieBreakDirection;// complex selection
	@auraEnabled public List<fieldPair> fieldPairs;

	public MRG_FallbackRule() {
		this.selectionType = 'simple';
		this.rule = 'Newest';
		this.conditions = new List<MRG_KeepRecordRule.condition>();
		this.fieldPairs = new List<fieldPair>();
		this.tieBreakDirection = 'DESC';
	}

	/*******************************************************************************************************
	* @description a source -> target field mapping for the fallback
	*/
	public class fieldPair {
		@auraEnabled public String sourceField;
		@auraEnabled public String targetField;
		public fieldPair() {}
		public fieldPair(String sourceField, String targetField) {
			this.sourceField = sourceField;
			this.targetField = targetField;
		}
	}

	/*******************************************************************************************************
	* @description the result of applying a fallback: which target field got which value, from which
	* source field and record. Returned so the merge engine can update the record and write history.
	*/
	public class applied {
		public String sourceField;
		public String targetField;
		public Object value;
		public Id sourceRecordId;
		public applied(String sourceField, String targetField, Object value, Id sourceRecordId) {
			this.sourceField = sourceField;
			this.targetField = targetField;
			this.value = value;
			this.sourceRecordId = sourceRecordId;
		}
	}

	/*******************************************************************************************************
	* @description all fields this rule reads/writes, so the caller can ensure they are queried
	* @return Set<String> field api names
	*/
	public Set<String> referencedFields() {
		Set<String> fields = new Set<String>();
		if(String.isNotBlank(tieBreakField))
			fields.add(tieBreakField);
		if(conditions != null) {
			for(MRG_KeepRecordRule.condition c:conditions) {
				if(String.isNotBlank(c.fieldName))
					fields.add(c.fieldName);
			}
		}
		if(fieldPairs != null) {
			for(fieldPair p:fieldPairs) {
				if(String.isNotBlank(p.sourceField)) fields.add(p.sourceField);
				if(String.isNotBlank(p.targetField)) fields.add(p.targetField);
			}
		}
		return fields;
	}

	/*******************************************************************************************************
	* @description selects the winning record for this fallback across a group
	* @param records the full merge group (kept + merged), each with CreatedDate populated for 'simple'
	* @return SObject the winning record, or null when none qualifies
	*/
	public SObject selectWinner(List<SObject> records) {
		if(records == null || records.isEmpty())
			return null;
		if(selectionType == 'complex')
			return toComplexRule().selectWinner(records);
		// simple: Oldest / Newest by CreatedDate
		SObject winner = null;
		for(SObject record:records) {
			if(winner == null) { winner = record; continue; }
			Datetime rc = (Datetime) record.get('CreatedDate');
			Datetime wc = (Datetime) winner.get('CreatedDate');
			if(rc == null || wc == null) continue;
			Boolean isNewest = rule == null || rule.equalsIgnoreCase('Newest');
			if(isNewest ? rc > wc : rc < wc)
				winner = record;
		}
		return winner;
	}

	/*******************************************************************************************************
	* @description builds the equivalent complex-selection rule (for the 'complex' selection path)
	*/
	private MRG_ComplexPreserveRule toComplexRule() {
		MRG_ComplexPreserveRule complexRule = new MRG_ComplexPreserveRule();
		complexRule.filterLogic = this.filterLogic;
		complexRule.conditions = this.conditions == null ? new List<MRG_KeepRecordRule.condition>() : this.conditions;
		complexRule.tieBreakField = this.tieBreakField;
		complexRule.tieBreakDirection = this.tieBreakDirection;
		// fieldName isn't used by selectWinner, only winningValue; leave null
		return complexRule;
	}

	/*******************************************************************************************************
	* @description applies the fallback to a kept record given the full group: routes each pair's source
	* value (from the winning record) into the target field on the kept record, only where the target is
	* currently empty and the source value is present. Mutates keptRecord and returns what was applied.
	* @param keptRecord the surviving record to write target fields onto
	* @param records the full merge group (kept + merged)
	* @return List<applied> the applied mappings (empty when nothing was routed)
	*/
	public List<applied> apply(SObject keptRecord, List<SObject> records) {
		List<applied> results = new List<applied>();
		if(keptRecord == null || fieldPairs == null || fieldPairs.isEmpty())
			return results;
		SObject winner = selectWinner(records);
		if(winner == null)
			return results;
		Id winnerId = (Id) winner.get('Id');
		for(fieldPair pair:fieldPairs) {
			if(String.isBlank(pair.sourceField) || String.isBlank(pair.targetField))
				continue;
			Object targetVal = keptRecord.get(pair.targetField);
			Object sourceVal = winner.get(pair.sourceField);
			// only fill an empty target, and only from a present source value
			if(isEmpty(targetVal) && !isEmpty(sourceVal)) {
				keptRecord.put(pair.targetField, sourceVal);
				results.add(new applied(pair.sourceField, pair.targetField, sourceVal, winnerId));
			}
		}
		return results;
	}

	/*******************************************************************************************************
	* @description treats null and blank string as empty
	*/
	private Boolean isEmpty(Object value) {
		if(value == null) return true;
		if(value instanceof String) return String.isBlank((String) value);
		return false;
	}
}
