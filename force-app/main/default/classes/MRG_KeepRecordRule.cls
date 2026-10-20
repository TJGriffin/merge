/**
* @author tj@tjgriffin.com
* @group Merge
* @description model + evaluation for the keep-record rules of an object. A rule is one comparative
* preference on one field (for example "prefer the record that has a Relationship Manager", "prefer the
* oldest record"). Rules are applied in order: each rule narrows the duplicate group to the records it
* prefers; the first rule that leaves exactly one record chooses the kept record. A rule that no record
* satisfies is skipped and the next rule sees the same group.
*
* Stateless: evaluation reads only the supplied SObjects and the rule's own definition.
* The nested condition class is unchanged and is shared with the complex-preserve and auto-merge-accounts
* rules.
*/
public with sharing class MRG_KeepRecordRule implements Comparable {

	public static final String PREFER_HAS_VALUE = 'HasValue';
	public static final String PREFER_IS_BLANK = 'IsBlank';
	public static final String PREFER_IS_TRUE = 'IsTrue';
	public static final String PREFER_IS_FALSE = 'IsFalse';
	public static final String PREFER_OLDEST = 'Oldest';
	public static final String PREFER_NEWEST = 'Newest';
	public static final String PREFER_LARGEST = 'Largest';
	public static final String PREFER_SMALLEST = 'Smallest';
	public static final String PREFER_LONGEST = 'Longest';
	public static final String PREFER_SHORTEST = 'Shortest';
	public static final String PREFER_EQUALS = 'Equals';
	public static final String PREFER_NOT_EQUALS = 'NotEquals';
	public static final String PREFER_CONTAINS = 'Contains';

	/*******************************************************************************************************
	* @description every preference the engine understands, in the order the UI offers them
	*/
	public static final List<String> PREFERENCES = new List<String>{
		PREFER_HAS_VALUE, PREFER_IS_BLANK, PREFER_IS_TRUE, PREFER_IS_FALSE, PREFER_OLDEST, PREFER_NEWEST,
		PREFER_LARGEST, PREFER_SMALLEST, PREFER_LONGEST, PREFER_SHORTEST, PREFER_EQUALS, PREFER_NOT_EQUALS, PREFER_CONTAINS
	};
	/*******************************************************************************************************
	* @description the preferences that compare the field with a configured value
	*/
	public static final Set<String> VALUE_PREFERENCES = new Set<String>{ PREFER_EQUALS, PREFER_NOT_EQUALS, PREFER_CONTAINS };

	@auraEnabled public String id;
	@auraEnabled public String label;
	@auraEnabled public String objectName;
	@auraEnabled public Integer order;
	@auraEnabled public String fieldName;
	@auraEnabled public String preference;
	@auraEnabled public String value;
	@auraEnabled public Boolean active;

	public MRG_KeepRecordRule() {
		this.order = 0;
		this.active = true;
	}

	/*******************************************************************************************************
	* @description builds a rule from a KeepRecordRuleSettings__mdt record
	* @param setting the metadata record (with Object__r.QualifiedAPIName selected)
	*/
	public MRG_KeepRecordRule(KeepRecordRuleSettings__mdt setting) {
		this.id = setting.Id;
		this.label = setting.Label;
		this.objectName = setting.Object__r != null ? setting.Object__r.QualifiedAPIName : null;
		this.order = setting.Order__c != null ? Integer.valueOf(setting.Order__c) : 0;
		this.fieldName = setting.Field__c;
		this.preference = setting.Preference__c;
		this.value = setting.Value__c;
		this.active = setting.Active__c != false;
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
	* @description whether the rule can be evaluated: a field, a known preference and, for the value
	* preferences, a value. Records saved by the previous condition-based rules have no preference and
	* are therefore ignored.
	* @return Boolean
	*/
	public Boolean isValid() {
		return String.isNotBlank(fieldName)
			&& preference != null && PREFERENCES.contains(preference)
			&& (!VALUE_PREFERENCES.contains(preference) || String.isNotBlank(value));
	}

	/*******************************************************************************************************
	* @description the field api names this rule reads (for SOQL building)
	* @return Set<String> field api names
	*/
	public Set<String> referencedFields() {
		Set<String> fields = new Set<String>();
		if(String.isNotBlank(fieldName))
			fields.add(fieldName);
		return fields;
	}

	/*******************************************************************************************************
	* @description the records this rule prefers out of a group. Empty when no record satisfies the
	* preference (for example every value is blank); several when they tie.
	* @param records the records to compare (with fieldName populated)
	* @return List<SObject> the preferred records, in the input order
	*/
	public List<SObject> prefer(List<SObject> records) {
		List<SObject> preferred = new List<SObject>();
		if(records == null || !isValid())
			return preferred;
		switch on preference {
			when 'HasValue' {
				for(SObject r:records) { if(!isBlank(r.get(fieldName))) preferred.add(r); }
			}
			when 'IsBlank' {
				for(SObject r:records) { if(isBlank(r.get(fieldName))) preferred.add(r); }
			}
			when 'IsTrue' {
				for(SObject r:records) { if(r.get(fieldName) == true) preferred.add(r); }
			}
			when 'IsFalse' {
				for(SObject r:records) { if(r.get(fieldName) != true) preferred.add(r); }
			}
			when 'Equals' {
				for(SObject r:records) { if(equalsValue(r.get(fieldName))) preferred.add(r); }
			}
			when 'NotEquals' {
				for(SObject r:records) { if(!equalsValue(r.get(fieldName))) preferred.add(r); }
			}
			when 'Contains' {
				for(SObject r:records) { if(containsValue(r.get(fieldName))) preferred.add(r); }
			}
			when 'Oldest', 'Smallest' {
				preferred = extreme(records, -1);
			}
			when 'Newest', 'Largest' {
				preferred = extreme(records, 1);
			}
			when 'Shortest' {
				preferred = extremeLength(records, -1);
			}
			when 'Longest' {
				preferred = extremeLength(records, 1);
			}
		}
		return preferred;
	}

	/*******************************************************************************************************
	* @description the records whose value is the minimum (direction -1) or maximum (direction 1) of the
	* group; blanks are ignored; ties are all returned
	*/
	private List<SObject> extreme(List<SObject> records, Integer direction) {
		List<SObject> out = new List<SObject>();
		Object best = null;
		for(SObject r:records) {
			Object v = r.get(fieldName);
			if(isBlank(v))
				continue;
			Integer cmp = best == null ? direction : compare(v, best);
			if(cmp * direction > 0) {
				best = v;
				out = new List<SObject>{ r };
			} else if(cmp == 0) {
				out.add(r);
			}
		}
		return out;
	}

	/*******************************************************************************************************
	* @description the records whose text is the shortest (direction -1) or longest (direction 1);
	* blanks are ignored; ties are all returned
	*/
	private List<SObject> extremeLength(List<SObject> records, Integer direction) {
		List<SObject> out = new List<SObject>();
		Integer best = null;
		for(SObject r:records) {
			Object v = r.get(fieldName);
			if(isBlank(v))
				continue;
			Integer len = String.valueOf(v).trim().length();
			Integer cmp = best == null ? direction : (len == best ? 0 : (len > best ? 1 : -1));
			if(cmp * direction > 0) {
				best = len;
				out = new List<SObject>{ r };
			} else if(cmp == 0) {
				out.add(r);
			}
		}
		return out;
	}

	private Boolean equalsValue(Object fieldVal) {
		if(isBlank(fieldVal))
			return String.isBlank(value);
		return String.valueOf(fieldVal).trim().equalsIgnoreCase(value.trim());
	}

	private Boolean containsValue(Object fieldVal) {
		return !isBlank(fieldVal) && String.isNotBlank(value) && String.valueOf(fieldVal).containsIgnoreCase(value.trim());
	}

	/*******************************************************************************************************
	* @description null, or a blank string
	*/
	@TestVisible private static Boolean isBlank(Object v) {
		return v == null || (v instanceof String && String.isBlank((String) v));
	}

	/*******************************************************************************************************
	* @description compares two non-null field values of the same type: dates, datetimes, times and
	* numbers by value, booleans false < true, anything else as case-insensitive text
	* @return Integer -1, 0 or 1
	*/
	@TestVisible private static Integer compare(Object a, Object b) {
		String type = MRG_Merge_SVC.getObjectType(a);
		switch on type {
			when 'Date' {
				Date x = (Date) a; Date y = (Date) b;
				return x < y ? -1 : (x > y ? 1 : 0);
			}
			when 'Datetime' {
				Datetime x = (Datetime) a; Datetime y = (Datetime) b;
				return x < y ? -1 : (x > y ? 1 : 0);
			}
			when 'Time' {
				Time x = (Time) a; Time y = (Time) b;
				return x < y ? -1 : (x > y ? 1 : 0);
			}
			when 'Integer', 'Long', 'Decimal', 'Double' {
				Decimal x = toDecimal(a); Decimal y = toDecimal(b);
				return x < y ? -1 : (x > y ? 1 : 0);
			}
			when 'Boolean' {
				Integer x = ((Boolean) a) ? 1 : 0; Integer y = ((Boolean) b) ? 1 : 0;
				return x == y ? 0 : (x > y ? 1 : -1);
			}
			when else {
				String x = String.valueOf(a).toLowerCase(); String y = String.valueOf(b).toLowerCase();
				return x < y ? -1 : (x > y ? 1 : 0);
			}
		}
	}

	private static Decimal toDecimal(Object v) {
		if(v instanceof Decimal) return (Decimal) v;
		if(v instanceof Integer) return (Integer) v;
		if(v instanceof Long) return (Long) v;
		if(v instanceof Double) return Decimal.valueOf((Double) v);
		return Decimal.valueOf(String.valueOf(v));
	}

	/*******************************************************************************************************
	* @description from an ordered list of rules and a duplicate group, returns the Id of the record to
	* keep. Each rule narrows the group to the records it prefers; the first rule that leaves exactly one
	* record selects it. A rule nobody satisfies is skipped. Returns null when the rules never single out
	* a record (the caller falls back to its default keep selection).
	* @param rules the keep-record rules of the object (any order)
	* @param records the candidate records (with the rules' fields populated)
	* @return Id the keep record id, or null when no rule produced a unique choice
	*/
	public static Id selectKeepId(List<MRG_KeepRecordRule> rules, List<SObject> records) {
		if(rules == null || rules.isEmpty() || records == null || records.size() < 2)
			return null;
		List<MRG_KeepRecordRule> ordered = new List<MRG_KeepRecordRule>(rules);
		ordered.sort();
		List<SObject> remaining = new List<SObject>(records);
		for(MRG_KeepRecordRule rule:ordered) {
			if(!rule.isValid())
				continue;
			List<SObject> preferred = rule.prefer(remaining);
			if(preferred.size() == 1)
				return (Id) preferred[0].get('Id');
			if(preferred.size() > 1)
				remaining = preferred;
		}
		return null;
	}

	/*******************************************************************************************************
	* @description every KeepRecordRuleSettings__mdt record (active or not), lazily queried
	*/
	public static List<MRG_KeepRecordRule> keepRecordRules {
		get {
			if(keepRecordRules == null) {
				List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>();
				for(KeepRecordRuleSettings__mdt setting:[
					SELECT Id, Label, QualifiedAPIName, Object__c, Object__r.QualifiedAPIName,
						Order__c, Field__c, Preference__c, Value__c, Active__c
					FROM KeepRecordRuleSettings__mdt
				]) {
					rules.add(new MRG_KeepRecordRule(setting));
				}
				keepRecordRules = rules;
			}
			return keepRecordRules;
		}
		set;
	}

	/*******************************************************************************************************
	* @description the active, valid keep-record rules of one object, sorted by evaluation order
	* @param objectType the SObject api name
	* @return List<MRG_KeepRecordRule> the rules (may be empty)
	*/
	public static List<MRG_KeepRecordRule> getRules(String objectType) {
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>();
		for(MRG_KeepRecordRule rule:keepRecordRules) {
			if(rule.active != false && rule.isValid() && String.isNotBlank(rule.objectName) && rule.objectName.equalsIgnoreCase(objectType))
				rules.add(rule);
		}
		rules.sort();
		return rules;
	}

	/*******************************************************************************************************
	* @description saves the ordered rules of one object via the Metadata API: the rules are numbered
	* 1..n in the given order (their developer names follow the position), and any stored rule of the
	* object beyond position n is deactivated, since custom metadata records cannot be deleted from Apex.
	* @param objectName the SObject api name
	* @param rules the rules in evaluation order
	* @return String the metadata deploy job id, or null when there is nothing to deploy
	*/
	public static String saveKeepRecordRules(String objectName, List<MRG_KeepRecordRule> rules) {
		List<MRG_KeepRecordRule> toSave = new List<MRG_KeepRecordRule>();
		Integer position = 1;
		for(MRG_KeepRecordRule rule:rules == null ? new List<MRG_KeepRecordRule>() : rules) {
			rule.objectName = objectName;
			rule.order = position;
			rule.active = true;
			rule.id = null;
			position++;
			toSave.add(rule);
		}
		for(MRG_KeepRecordRule stored:keepRecordRules) {
			if(String.isNotBlank(stored.objectName) && stored.objectName.equalsIgnoreCase(objectName)
				&& stored.order != null && stored.order >= position && stored.active != false) {
				MRG_KeepRecordRule retired = new MRG_KeepRecordRule();
				retired.objectName = objectName;
				retired.order = stored.order;
				retired.label = stored.label;
				retired.fieldName = stored.fieldName;
				retired.preference = stored.preference;
				retired.value = stored.value;
				retired.active = false;
				toSave.add(retired);
			}
		}
		MRG_Metadata_SVC mdService = new MRG_Metadata_SVC();
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		for(MRG_KeepRecordRule rule:toSave)
			mdRecords.add(mdService.getMetaDataRecord(toSetting(rule)));
		return mdService.deployMetadataRecords(mdRecords);
	}

	/*******************************************************************************************************
	* @description the developer name of the rule stored at a position for an object
	* @param objectName the SObject api name
	* @param order the position (1-based)
	* @return String the developer name
	*/
	public static String developerName(String objectName, Integer order) {
		return (objectName == null ? 'Obj' : objectName.replace('__','').replace('_','')) + 'KeepRule' + order;
	}

	/*******************************************************************************************************
	* @description converts a rule into a KeepRecordRuleSettings__mdt record, populating the read-only
	* Object__r relationship via JSON injection (mirrors the existing settings-save pattern)
	* @param rule the rule
	* @return KeepRecordRuleSettings__mdt the metadata record
	*/
	public static KeepRecordRuleSettings__mdt toSetting(MRG_KeepRecordRule rule) {
		String label = String.isNotBlank(rule.label) ? rule.label : (rule.objectName + ' keep rule ' + rule.order + ': ' + rule.preference + ' ' + rule.fieldName);
		KeepRecordRuleSettings__mdt setting = new KeepRecordRuleSettings__mdt(
			Label = label.length() > 40 ? label.substring(0, 40) : label,
			Order__c = rule.order,
			Field__c = rule.fieldName,
			Preference__c = rule.preference,
			Value__c = VALUE_PREFERENCES.contains(rule.preference) ? rule.value : null,
			Active__c = rule.active != false
		);
		setting.QualifiedAPIName = developerName(rule.objectName, rule.order);
		Map<String, Object> settingJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(setting));
		settingJSON.put('Object__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' },
			'QualifiedAPIName' => rule.objectName
		});
		if(String.isNotBlank(rule.id))
			settingJSON.put('Id', rule.id);
		return (KeepRecordRuleSettings__mdt) JSON.deserialize(JSON.serialize(settingJSON), KeepRecordRuleSettings__mdt.class);
	}

	/*******************************************************************************************************
	* @description a single condition: a field, an operator, and a comparison value. Used by the
	* complex-preserve and auto-merge-accounts rules (not by the keep-record rules themselves).
	*/
	public class condition {
		@auraEnabled public String fieldName;
		@auraEnabled public String operator;   // equals, notEquals, lessThan, lessOrEqual, greaterThan, greaterOrEqual, contains, startsWith, endsWith
		@auraEnabled public String value;      // raw string value; typed via the record's field type
		@auraEnabled public String aggregator; // optional cross-record aggregator (all/any/differ/same)
		                                       // used by group-level rules; ignored by single-record use

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
}
