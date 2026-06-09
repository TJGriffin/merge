/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit tests for keep-record rule conditions, matching, and ordered keep selection
*/
@isTest
private class MRG_KeepRecordRule_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val) {
		return new MRG_KeepRecordRule.condition(field, op, val);
	}

	static testMethod void testEqualsAndNotEquals() {
		Contact c = new Contact(LastName='Smith', MailingState='TX');
		system.assert(cond('MailingState','equals','TX').evaluate(c));
		system.assert(!cond('MailingState','equals','CA').evaluate(c));
		system.assert(cond('MailingState','notEquals','CA').evaluate(c));
		// null field equals blank value
		Contact blank = new Contact(LastName='X');
		system.assert(cond('MailingState','equals','').evaluate(blank), 'null field equals blank');
		system.assert(!cond('MailingState','equals','TX').evaluate(blank));
	}

	static testMethod void testBooleanEquals() {
		Contact c = new Contact(LastName='X', HasOptedOutOfEmail=true);
		system.assert(cond('HasOptedOutOfEmail','equals','true').evaluate(c));
		system.assert(!cond('HasOptedOutOfEmail','equals','false').evaluate(c));
		system.assert(cond('HasOptedOutOfEmail','notEquals','false').evaluate(c));
	}

	static testMethod void testStringOperators() {
		Contact c = new Contact(LastName='Johnson');
		system.assert(cond('LastName','contains','ohns').evaluate(c));
		system.assert(cond('LastName','startsWith','John').evaluate(c));
		system.assert(cond('LastName','endsWith','son').evaluate(c));
		system.assert(!cond('LastName','contains','xyz').evaluate(c));
	}

	static testMethod void testOrderedDateOperators() {
		Contact c = new Contact(LastName='X', Birthdate=Date.newInstance(2000,1,1));
		system.assert(cond('Birthdate','greaterThan','1999-01-01').evaluate(c));
		system.assert(cond('Birthdate','lessThan','2001-01-01').evaluate(c));
		system.assert(cond('Birthdate','greaterOrEqual','2000-01-01').evaluate(c));
		system.assert(cond('Birthdate','lessOrEqual','2000-01-01').evaluate(c));
		system.assert(!cond('Birthdate','greaterThan','2001-01-01').evaluate(c));
		// null field -> ordered comparison false
		system.assert(!cond('Birthdate','greaterThan','2000-01-01').evaluate(new Contact(LastName='Y')));
		// unparseable comparison value -> false, not an exception
		system.assert(!cond('Birthdate','greaterThan','not-a-date').evaluate(c));
	}

	static testMethod void testMatchesUsesFilterLogic() {
		Contact c = new Contact(LastName='X', MailingState='TX', HasOptedOutOfEmail=true);
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.filterLogic = '1 OR 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('MailingState','equals','CA'),      // false
			cond('HasOptedOutOfEmail','equals','true') // true
		};
		system.assert(rule.matches(c), '1 OR 2 with second true should match');

		rule.filterLogic = '1 AND 2';
		system.assert(!rule.matches(c), '1 AND 2 with first false should not match');
	}

	static testMethod void testMatchesEmptyConditionsIsFalse() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		system.assert(!rule.matches(new Contact(LastName='X')), 'no conditions -> no match');
	}

	static testMethod void testReferencedFields() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('MailingState','equals','TX'),
			cond('Birthdate','greaterThan','2000-01-01')
		};
		system.assertEquals(new Set<String>{'MailingState','Birthdate'}, rule.referencedFields());
	}

	static testMethod void testSelectKeepIdUniqueMatchWins() {
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', MailingState='TX'),
			new Contact(FirstName='B', LastName='B', MailingState='CA')
		};
		insert cons;

		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.order = 1;
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('MailingState','equals','CA') };

		List<Contact> queried = [SELECT Id, MailingState FROM Contact];
		Id keepId = MRG_KeepRecordRule.selectKeepId(new List<MRG_KeepRecordRule>{ rule }, queried);
		system.assertEquals(cons[1].Id, keepId, 'the single CA record should be chosen');
	}

	static testMethod void testSelectKeepIdSkipsAmbiguousFallsToNextRule() {
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', MailingState='TX', HasOptedOutOfEmail=true),
			new Contact(FirstName='B', LastName='B', MailingState='TX', HasOptedOutOfEmail=false)
		};
		insert cons;
		List<Contact> queried = [SELECT Id, MailingState, HasOptedOutOfEmail FROM Contact];

		// rule 1 matches BOTH (state=TX) -> ambiguous, skipped
		MRG_KeepRecordRule rule1 = new MRG_KeepRecordRule();
		rule1.order = 1;
		rule1.conditions = new List<MRG_KeepRecordRule.condition>{ cond('MailingState','equals','TX') };
		// rule 2 matches exactly one (opted out) -> wins
		MRG_KeepRecordRule rule2 = new MRG_KeepRecordRule();
		rule2.order = 2;
		rule2.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };

		Id keepId = MRG_KeepRecordRule.selectKeepId(new List<MRG_KeepRecordRule>{ rule2, rule1 }, queried);
		system.assertEquals(cons[0].Id, keepId, 'rule order should be respected and ambiguous rule skipped');
	}

	static testMethod void testSelectKeepIdNoMatchReturnsNull() {
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', MailingState='TX'),
			new Contact(FirstName='B', LastName='B', MailingState='TX')
		};
		insert cons;
		List<Contact> queried = [SELECT Id, MailingState FROM Contact];
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('MailingState','equals','CA') };
		system.assertEquals(null, MRG_KeepRecordRule.selectKeepId(new List<MRG_KeepRecordRule>{ rule }, queried),
			'no unique match -> null (caller uses default)');
	}

	static testMethod void testCompareToOrders() {
		MRG_KeepRecordRule a = new MRG_KeepRecordRule(); a.order = 2;
		MRG_KeepRecordRule b = new MRG_KeepRecordRule(); b.order = 1;
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{ a, b };
		rules.sort();
		system.assertEquals(1, rules[0].order, 'lower order sorts first');
	}
}
