/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit tests for the standalone Fallback rule model + evaluation
*/
@isTest
private class MRG_FallbackRule_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val) {
		return new MRG_KeepRecordRule.condition(field, op, val);
	}

	static testMethod void testReferencedFields() {
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'complex';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakField = 'Birthdate';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{
			new MRG_FallbackRule.fieldPair('Email', 'Description')
		};
		Set<String> fields = rule.referencedFields();
		system.assert(fields.contains('Email') && fields.contains('Description'), 'pair fields');
		system.assert(fields.contains('Birthdate'), 'tie-break field');
		system.assert(fields.contains('HasOptedOutOfEmail'), 'condition field');
	}

	static testMethod void testSimpleNewestSelectionAndApply() {
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='Old', LastName='A', Email='old@test.com'),
			new Contact(FirstName='New', LastName='B', Email='new@test.com')
		};
		insert cons;
		Test.setCreatedDate(cons[0].Id, Datetime.now().addDays(-30));
		Test.setCreatedDate(cons[1].Id, Datetime.now().addDays(-1));
		List<Contact> recs = [SELECT Id, CreatedDate, Email, Description FROM Contact];

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'simple';
		rule.rule = 'Newest';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		// kept record has an empty Description target
		Contact kept = new Contact(Id=cons[0].Id, Description=null);
		List<MRG_FallbackRule.applied> applied = rule.apply(kept, recs);

		system.assertEquals(1, applied.size(), 'one pair applied');
		system.assertEquals('new@test.com', (String) kept.get('Description'), 'newest record email routed to Description');
		system.assertEquals('Email', applied[0].sourceField);
		system.assertEquals('Description', applied[0].targetField);
	}

	static testMethod void testTargetMustBeEmpty() {
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', Email='a@test.com')
		};
		insert cons;
		List<Contact> recs = [SELECT Id, CreatedDate, Email, Description FROM Contact];

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'simple';
		rule.rule = 'Newest';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		// target already populated -> not overwritten
		Contact kept = new Contact(Id=cons[0].Id, Description='already here');
		List<MRG_FallbackRule.applied> applied = rule.apply(kept, recs);
		system.assertEquals(0, applied.size(), 'non-empty target is not overwritten');
		system.assertEquals('already here', (String) kept.get('Description'));
	}

	static testMethod void testComplexSelectionRoutesFromWinningRecord() {
		// among opted-out records, prefer the newest birthdate; route its Email to Description
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', Email='nope@test.com', HasOptedOutOfEmail=false, Birthdate=Date.newInstance(2010,1,1)),
			new Contact(FirstName='B', LastName='B', Email='older@test.com', HasOptedOutOfEmail=true, Birthdate=Date.newInstance(1980,1,1)),
			new Contact(FirstName='C', LastName='C', Email='win@test.com', HasOptedOutOfEmail=true, Birthdate=Date.newInstance(2000,1,1))
		};
		insert cons;
		List<Contact> recs = [SELECT Id, CreatedDate, Email, Description, HasOptedOutOfEmail, Birthdate FROM Contact];

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'complex';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakField = 'Birthdate';
		rule.tieBreakDirection = 'DESC';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		Contact kept = new Contact(Id=cons[0].Id, Description=null);
		List<MRG_FallbackRule.applied> applied = rule.apply(kept, recs);
		system.assertEquals('win@test.com', (String) kept.get('Description'),
			'complex winner (opted-out, newest birthdate) email routed to target');
	}

	static testMethod void testMultiPairSameRecord() {
		// two pairs from the SAME winning record stay consistent
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='Win', LastName='W', Email='win@test.com', MailingState='WA', HasOptedOutOfEmail=true),
			new Contact(FirstName='Lose', LastName='L', Email='lose@test.com', MailingState='CA', HasOptedOutOfEmail=false)
		};
		insert cons;
		List<Contact> recs = [SELECT Id, CreatedDate, Email, Description, MailingState, OtherCity, HasOptedOutOfEmail FROM Contact];

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'complex';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{
			new MRG_FallbackRule.fieldPair('Email','Description'),
			new MRG_FallbackRule.fieldPair('MailingState','OtherCity')
		};

		Contact kept = new Contact(Id=cons[1].Id, Description=null, OtherCity=null);
		List<MRG_FallbackRule.applied> applied = rule.apply(kept, recs);
		system.assertEquals(2, applied.size(), 'both pairs applied from the same winner');
		system.assertEquals('win@test.com', (String) kept.get('Description'));
		system.assertEquals('WA', (String) kept.get('OtherCity'));
		// both came from the same winning record
		system.assertEquals(applied[0].sourceRecordId, applied[1].sourceRecordId, 'same winning record for all pairs');
	}

	static testMethod void testNoWinnerNoApply() {
		List<Contact> cons = new List<Contact>{ new Contact(FirstName='A', LastName='A', HasOptedOutOfEmail=false) };
		insert cons;
		List<Contact> recs = [SELECT Id, CreatedDate, Email, Description, HasOptedOutOfEmail FROM Contact];
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.selectionType = 'complex';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };
		Contact kept = new Contact(Id=cons[0].Id);
		system.assertEquals(0, rule.apply(kept, recs).size(), 'no condition match -> nothing applied');
	}
}
