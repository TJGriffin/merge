/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit tests for the group-wide complex-preservation rule evaluator
*/
@isTest
private class MRG_ComplexPreserveRule_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val) {
		return new MRG_KeepRecordRule.condition(field, op, val);
	}

	// the example from the ticket: preserve MailingStreet when HasOptedOutOfEmail=true; if more than
	// one matches, prefer the latest Birthdate (tie-break DESC)
	private static MRG_ComplexPreserveRule ticketRule() {
		MRG_ComplexPreserveRule rule = new MRG_ComplexPreserveRule();
		rule.fieldName = 'MailingStreet';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakField = 'Birthdate';
		rule.tieBreakDirection = 'DESC';
		return rule;
	}

	static testMethod void testReferencedFields() {
		MRG_ComplexPreserveRule rule = ticketRule();
		Set<String> fields = rule.referencedFields();
		system.assert(fields.contains('MailingStreet'), 'target field');
		system.assert(fields.contains('Birthdate'), 'tie-break field');
		system.assert(fields.contains('HasOptedOutOfEmail'), 'condition field');
	}

	static testMethod void testNoMatchReturnsNull() {
		MRG_ComplexPreserveRule rule = ticketRule();
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=false, MailingStreet='1 St'),
			new Contact(LastName='B', HasOptedOutOfEmail=false, MailingStreet='2 St')
		};
		system.assertEquals(null, rule.winningValue(recs), 'no record matches the condition -> null');
	}

	static testMethod void testSingleMatchWins() {
		MRG_ComplexPreserveRule rule = ticketRule();
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=false, MailingStreet='1 St'),
			new Contact(LastName='B', HasOptedOutOfEmail=true,  MailingStreet='2 St', Birthdate=Date.newInstance(1990,1,1))
		};
		system.assertEquals('2 St', (String) rule.winningValue(recs), 'the single matching record value is preserved');
	}

	static testMethod void testTieBreakDescPicksLatest() {
		MRG_ComplexPreserveRule rule = ticketRule(); // DESC on Birthdate
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=true, MailingStreet='older', Birthdate=Date.newInstance(1980,1,1)),
			new Contact(LastName='B', HasOptedOutOfEmail=true, MailingStreet='newer', Birthdate=Date.newInstance(2000,1,1))
		};
		system.assertEquals('newer', (String) rule.winningValue(recs), 'DESC tie-break prefers the latest Birthdate');
	}

	static testMethod void testTieBreakAscPicksEarliest() {
		MRG_ComplexPreserveRule rule = ticketRule();
		rule.tieBreakDirection = 'ASC';
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=true, MailingStreet='older', Birthdate=Date.newInstance(1980,1,1)),
			new Contact(LastName='B', HasOptedOutOfEmail=true, MailingStreet='newer', Birthdate=Date.newInstance(2000,1,1))
		};
		system.assertEquals('older', (String) rule.winningValue(recs), 'ASC tie-break prefers the earliest Birthdate');
	}

	static testMethod void testTieBreakNumberDesc() {
		// Accounts with a numeric tie-break field
		List<Account> recs = new List<Account>{
			new Account(Name='A', NumberOfEmployees=10),
			new Account(Name='B', NumberOfEmployees=500)
		};
		MRG_ComplexPreserveRule numRule = new MRG_ComplexPreserveRule();
		numRule.fieldName = 'Name';
		numRule.filterLogic = '';
		numRule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('NumberOfEmployees','greaterThan','0') };
		numRule.tieBreakField = 'NumberOfEmployees';
		numRule.tieBreakDirection = 'DESC';
		system.assertEquals('B', (String) numRule.winningValue(recs), 'DESC numeric tie-break picks the larger employee count record');
	}

	static testMethod void testNullTieBreakValuesSortLast() {
		MRG_ComplexPreserveRule rule = ticketRule(); // DESC on Birthdate
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=true, MailingStreet='has-date', Birthdate=Date.newInstance(1990,1,1)),
			new Contact(LastName='B', HasOptedOutOfEmail=true, MailingStreet='no-date', Birthdate=null)
		};
		system.assertEquals('has-date', (String) rule.winningValue(recs), 'record with a tie-break value should win over a null');
	}

	// build a Contact with a read-only CreatedDate set (via JSON) for Oldest/Newest tie-break tests
	private static Contact contactWithCreated(String last, Boolean optedOut, String street, Datetime created, Date bday) {
		Map<String, Object> m = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'Contact' },
			'LastName' => last,
			'HasOptedOutOfEmail' => optedOut,
			'MailingStreet' => street,
			'CreatedDate' => created,
			'Birthdate' => bday
		};
		return (Contact) JSON.deserialize(JSON.serialize(m), Contact.class);
	}

	static testMethod void testTieBreakRuleLargest() {
		List<Account> recs = new List<Account>{
			new Account(Name='small', NumberOfEmployees=10),
			new Account(Name='big', NumberOfEmployees=500)
		};
		MRG_ComplexPreserveRule rule = new MRG_ComplexPreserveRule();
		rule.fieldName = 'Name';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('NumberOfEmployees','greaterThan','0') };
		rule.tieBreakRule = 'Largest';
		rule.tieBreakField = 'NumberOfEmployees';
		system.assertEquals('big', (String) rule.winningValue(recs), 'Largest rule picks the larger NumberOfEmployees');
	}

	static testMethod void testTieBreakRuleLongest() {
		List<Contact> recs = new List<Contact>{
			new Contact(LastName='A', HasOptedOutOfEmail=true, MailingStreet='123 Main Street, Suite 400'),
			new Contact(LastName='B', HasOptedOutOfEmail=true, MailingStreet='1 Elm')
		};
		MRG_ComplexPreserveRule rule = new MRG_ComplexPreserveRule();
		rule.fieldName = 'LastName';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakRule = 'Longest';
		rule.tieBreakField = 'MailingStreet';
		system.assertEquals('A', (String) rule.winningValue(recs), 'Longest rule picks the record with the longer MailingStreet');
	}

	static testMethod void testTieBreakRuleThenSecondaryField() {
		Datetime same = Datetime.newInstance(2020, 1, 1, 0, 0, 0);
		List<Contact> recs = new List<Contact>{
			contactWithCreated('A', true, 'a', same, Date.newInstance(1980,1,1)),
			contactWithCreated('B', true, 'b', same, Date.newInstance(2000,1,1))
		};
		MRG_ComplexPreserveRule rule = new MRG_ComplexPreserveRule();
		rule.fieldName = 'MailingStreet';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakRule = 'Newest';       // primary: CreatedDate (tied here)
		rule.tieBreakField = 'Birthdate';   // secondary
		rule.tieBreakDirection = 'DESC';
		system.assertEquals('b', (String) rule.winningValue(recs), 'CreatedDate tie falls back to the secondary Birthdate DESC');
	}

	static testMethod void testEmptyConditionsNeverMatch() {
		MRG_ComplexPreserveRule rule = new MRG_ComplexPreserveRule();
		rule.fieldName = 'MailingStreet';
		system.assertEquals(null, rule.winningValue(new List<Contact>{ new Contact(LastName='A') }),
			'no conditions -> no winner');
	}
}
