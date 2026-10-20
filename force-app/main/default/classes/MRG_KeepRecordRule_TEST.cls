/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the comparative keep-record rule engine (MRG_KeepRecordRule)
*/
@isTest
private class MRG_KeepRecordRule_TEST {

	private static MRG_KeepRecordRule rule(Integer order, String field, String preference, String value) {
		MRG_KeepRecordRule r = new MRG_KeepRecordRule();
		r.objectName = 'Account';
		r.order = order;
		r.fieldName = field;
		r.preference = preference;
		r.value = value;
		return r;
	}

	private static Account acct(String name, String site, String type, Integer employees, Decimal revenue) {
		return new Account(Name=name, Site=site, Type=type, NumberOfEmployees=employees, AnnualRevenue=revenue);
	}

	private static Set<Id> ids(List<SObject> records) {
		Set<Id> out = new Set<Id>();
		for(SObject r:records) out.add((Id) r.get('Id'));
		return out;
	}

	static testMethod void testHasValueThenOldest() {
		// the brief: prefer the Account with a Relationship Manager (here: Site), then the oldest
		List<Account> accts = new List<Account>{ acct('Alone', null, null, null, null), acct('Family', 'Kent Anderson', null, null, null) };
		insert accts;
		List<Account> recs = [SELECT Id, Site, CreatedDate FROM Account ORDER BY CreatedDate, Id];
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ rule(2, 'CreatedDate', 'Oldest', null), rule(1, 'Site', 'HasValue', null) };

		system.assertEquals(accts[1].Id, MRG_KeepRecordRule.selectKeepId(rules, recs), 'the record with a Site wins rule 1 regardless of age or list order');
	}

	static testMethod void testSkippedRuleFallsThroughToNext() {
		List<Account> accts = new List<Account>{ acct('A', null, 'Prospect', null, null), acct('B', null, 'Customer', null, null) };
		insert accts;
		List<Account> recs = [SELECT Id, Site, Type FROM Account];
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ rule(1, 'Site', 'HasValue', null), rule(2, 'Type', 'Equals', 'customer') };

		system.assertEquals(accts[1].Id, MRG_KeepRecordRule.selectKeepId(rules, recs), 'nobody has a Site -> rule 1 skipped; Equals is case-insensitive');
	}

	static testMethod void testTieNarrowsThenNextRuleDecides() {
		List<Account> accts = new List<Account>{ acct('A', 'x', null, 5, null), acct('B', 'y', null, 50, null), acct('C', null, null, 500, null) };
		insert accts;
		List<Account> recs = [SELECT Id, Site, NumberOfEmployees FROM Account];
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ rule(1, 'Site', 'HasValue', null), rule(2, 'NumberOfEmployees', 'Largest', null) };

		system.assertEquals(accts[1].Id, MRG_KeepRecordRule.selectKeepId(rules, recs), 'A and B tie on rule 1; C (most employees) is already out, so B wins rule 2');
	}

	static testMethod void testNoUniqueChoiceReturnsNull() {
		List<Account> accts = new List<Account>{ acct('A', 'x', null, 5, null), acct('B', 'y', null, 5, null) };
		insert accts;
		List<Account> recs = [SELECT Id, Site, NumberOfEmployees FROM Account];
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ rule(1, 'Site', 'HasValue', null), rule(2, 'NumberOfEmployees', 'Smallest', null) };

		system.assertEquals(null, MRG_KeepRecordRule.selectKeepId(rules, recs), 'a full tie leaves the caller its default');
		system.assertEquals(null, MRG_KeepRecordRule.selectKeepId(new List<MRG_KeepRecordRule>(), recs), 'no rules');
		system.assertEquals(null, MRG_KeepRecordRule.selectKeepId(rules, new List<SObject>{ recs[0] }), 'a single record is nothing to choose between');
	}

	static testMethod void testInvalidAndInactiveRulesIgnored() {
		List<Account> accts = new List<Account>{ acct('A', 'x', null, null, null), acct('B', null, null, null, null) };
		insert accts;
		List<Account> recs = [SELECT Id, Site FROM Account];
		MRG_KeepRecordRule noField = rule(1, null, 'HasValue', null);
		MRG_KeepRecordRule badPreference = rule(2, 'Site', 'Whatever', null);
		MRG_KeepRecordRule valueMissing = rule(3, 'Site', 'Equals', null);
		MRG_KeepRecordRule legacy = rule(4, null, null, null);
		MRG_KeepRecordRule good = rule(5, 'Site', 'HasValue', null);
		system.assertEquals(false, noField.isValid());
		system.assertEquals(false, badPreference.isValid());
		system.assertEquals(false, valueMissing.isValid());
		system.assertEquals(false, legacy.isValid());
		system.assertEquals(true, good.isValid());
		system.assertEquals(accts[0].Id, MRG_KeepRecordRule.selectKeepId(new List<MRG_KeepRecordRule>{ noField, badPreference, valueMissing, legacy, good }, recs));
		system.assertEquals(0, badPreference.prefer(recs).size(), 'an invalid rule prefers nothing');
	}

	static testMethod void testEveryPreference() {
		List<Account> accts = new List<Account>{
			acct('Alpha', 'HQ', 'Customer - Direct', 10, 100),
			acct('Beta', null, 'Prospect', 300, 50),
			acct('Gamma', 'Branch office', 'Customer - Channel', 20, null)
		};
		insert accts;
		List<Account> recs = [SELECT Id, Name, Site, Type, NumberOfEmployees, AnnualRevenue, CreatedDate FROM Account];
		Id alpha = accts[0].Id, beta = accts[1].Id, gamma = accts[2].Id;

		system.assertEquals(new Set<Id>{ alpha, gamma }, ids(rule(1, 'Site', 'HasValue', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ beta }, ids(rule(1, 'Site', 'IsBlank', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ beta }, ids(rule(1, 'NumberOfEmployees', 'Largest', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha }, ids(rule(1, 'NumberOfEmployees', 'Smallest', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha }, ids(rule(1, 'AnnualRevenue', 'Largest', null).prefer(recs)), 'blank revenue is ignored');
		system.assertEquals(new Set<Id>{ gamma }, ids(rule(1, 'Site', 'Longest', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha }, ids(rule(1, 'Site', 'Shortest', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha }, ids(rule(1, 'Type', 'Equals', 'customer - direct').prefer(recs)));
		system.assertEquals(new Set<Id>{ beta, gamma }, ids(rule(1, 'Type', 'NotEquals', 'Customer - Direct').prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha, gamma }, ids(rule(1, 'Type', 'Contains', 'CUSTOMER').prefer(recs)));
		system.assertEquals(new Set<Id>{ alpha }, ids(rule(1, 'Name', 'Smallest', null).prefer(recs)), 'text compares alphabetically');
		system.assert(rule(1, 'CreatedDate', 'Oldest', null).prefer(recs).size() >= 1, 'the oldest datetime is found');
		system.assert(rule(1, 'CreatedDate', 'Newest', null).prefer(recs).size() >= 1, 'the newest datetime is found');
	}

	static testMethod void testBooleanPreferences() {
		List<Contact> cons = new List<Contact>{
			new Contact(LastName='Opted', HasOptedOutOfEmail=true),
			new Contact(LastName='Subscribed', HasOptedOutOfEmail=false)
		};
		insert cons;
		List<Contact> recs = [SELECT Id, HasOptedOutOfEmail FROM Contact];
		system.assertEquals(new Set<Id>{ cons[0].Id }, ids(rule(1, 'HasOptedOutOfEmail', 'IsTrue', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ cons[1].Id }, ids(rule(1, 'HasOptedOutOfEmail', 'IsFalse', null).prefer(recs)));
		system.assertEquals(new Set<Id>{ cons[1].Id }, ids(rule(1, 'HasOptedOutOfEmail', 'Smallest', null).prefer(recs)), 'false < true');
	}

	static testMethod void testCompareTypes() {
		system.assertEquals(-1, MRG_KeepRecordRule.compare(Date.newInstance(2020, 1, 1), Date.newInstance(2021, 1, 1)));
		system.assertEquals(1, MRG_KeepRecordRule.compare(Datetime.newInstance(2021, 1, 1, 0, 0, 0), Datetime.newInstance(2020, 1, 1, 0, 0, 0)));
		system.assertEquals(0, MRG_KeepRecordRule.compare(Time.newInstance(1, 0, 0, 0), Time.newInstance(1, 0, 0, 0)));
		system.assertEquals(1, MRG_KeepRecordRule.compare(10, 9));
		system.assertEquals(-1, MRG_KeepRecordRule.compare(1.5, 2.5));
		system.assertEquals(1, MRG_KeepRecordRule.compare((Double) 3.0, (Double) 2.0));
		system.assertEquals(-1, MRG_KeepRecordRule.compare(false, true));
		system.assertEquals(0, MRG_KeepRecordRule.compare('abc', 'ABC'));
		system.assertEquals(true, MRG_KeepRecordRule.isBlank('  '));
		system.assertEquals(false, MRG_KeepRecordRule.isBlank(0));
	}

	static testMethod void testSortsByOrder() {
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ rule(3, 'a', 'HasValue', null), rule(1, 'b', 'HasValue', null), rule(2, 'c', 'HasValue', null) };
		rules.sort();
		system.assertEquals('b', rules[0].fieldName);
		system.assertEquals('c', rules[1].fieldName);
		system.assertEquals('a', rules[2].fieldName);
		system.assertEquals(new Set<String>{ 'a' }, rules[2].referencedFields());
	}
}
