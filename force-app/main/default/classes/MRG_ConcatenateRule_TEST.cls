/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit + end-to-end tests for the Concatenate preservation rule (#88): unique values
* across the merge candidates kept as one delimited string, truncated to the field length.
*/
@isTest
private class MRG_ConcatenateRule_TEST {

	static testMethod void testConcatenateDedupesAndJoins() {
		system.assertEquals('A;B;C', (String) MRG_Merge_SVC.concatenateValues('A;B', 'B;C', ';', 255, false),
			'unique values are joined once, preserving order');
	}

	static testMethod void testConcatenateCustomCharacter() {
		// a regex-special delimiter must be treated literally
		system.assertEquals('A|B|C', (String) MRG_Merge_SVC.concatenateValues('A|B', 'C', '|', 255, false),
			'custom (regex-special) delimiter joins and splits literally');
		system.assertEquals('A|B', (String) MRG_Merge_SVC.concatenateValues('A|B', 'B', '|', 255, false),
			'value already present is not repeated');
	}

	static testMethod void testConcatenateTrimsAndDropsBlanks() {
		system.assertEquals('A;B;C', (String) MRG_Merge_SVC.concatenateValues(' A ; B ', 'B; C ;', ';', 255, false),
			'values are trimmed and empty segments dropped');
	}

	static testMethod void testConcatenateHandlesNulls() {
		system.assertEquals('A;B', (String) MRG_Merge_SVC.concatenateValues('A;B', null, ';', 255, false), 'null merge value -> keep value');
		system.assertEquals('X', (String) MRG_Merge_SVC.concatenateValues(null, 'X', ';', 255, false), 'null keep value -> merge value');
		system.assertEquals('', (String) MRG_Merge_SVC.concatenateValues(null, null, ';', 255, false), 'both null -> empty');
	}

	static testMethod void testConcatenateTruncatesStringValue() {
		// a plain string is hard-truncated to the field length
		system.assertEquals('AAAA;B', (String) MRG_Merge_SVC.concatenateValues('AAAA', 'BBBB', ';', 6, false),
			'string result is truncated to the max length');
	}

	static testMethod void testConcatenateTruncatesMultiselectOnWholeValues() {
		// a multiselect drops whole values that do not fit (a partial value would be invalid)
		system.assertEquals('AAAA', (String) MRG_Merge_SVC.concatenateValues('AAAA', 'BBBB', ';', 6, true),
			'multiselect truncation drops the whole value that does not fit');
		system.assertEquals('A;B', (String) MRG_Merge_SVC.concatenateValues('A;B', 'CCCC', ';', 4, true),
			'multiselect keeps all values that fit');
	}

	static testMethod void testConcatenateNoTruncationWhenLengthUnknown() {
		system.assertEquals('AAAA;BBBB', (String) MRG_Merge_SVC.concatenateValues('AAAA', 'BBBB', ';', 0, false),
			'a zero max length means no truncation');
	}

	static testMethod void testIsConcatenatableField() {
		system.assertEquals(true, MRG_Merge_SVC.isConcatenatableField('Contact', 'MailingState'), 'a string field is concatenatable');
		system.assertEquals(false, MRG_Merge_SVC.isConcatenatableField('Contact', 'Email'), 'an email field is not concatenatable');
		system.assertEquals(false, MRG_Merge_SVC.isConcatenatableField('Contact', 'Birthdate'), 'a date field is not concatenatable');
		system.assertEquals(false, MRG_Merge_SVC.isConcatenatableField('Contact', 'NoSuchField__x'), 'unknown field -> false');
		system.assertEquals(false, MRG_Merge_SVC.isConcatenatableField('NoSuchObject__x', 'Email'), 'unknown object -> false');
		system.assertEquals(false, MRG_Merge_SVC.isConcatenatableField('Contact', ''), 'blank field -> false');
	}

	static testMethod void testGetFieldLength() {
		system.assert(MRG_Merge_SVC.getFieldLength('Contact', 'MailingState') > 0, 'a real string field has a length');
		system.assertEquals(0, MRG_Merge_SVC.getFieldLength('Contact', 'NoSuchField__x'), 'unknown field -> 0');
		system.assertEquals(0, MRG_Merge_SVC.getFieldLength('NoSuchObject__x', 'MailingState'), 'unknown object -> 0');
	}

	static testMethod void testContactConcatenateEndToEnd() {
		// default character (;): unique values across both records survive on the kept record
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='A;B'),
			new Contact(Id=mergeId, MailingState='B;C')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Concatenate')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('A;B;C', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Concatenate keeps the unique values joined by the default semicolon');
		system.assert(MRG_TestFactory.historyByField(keepId).containsKey('mailingstate'),
			'changed preserved field should be tracked');
	}

	static testMethod void testContactConcatenateCustomCharacterEndToEnd() {
		// configured character (|) joins the unique values
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='A|B'),
			new Contact(Id=mergeId, MailingState='C')
		};
		MergeFieldSetting__mdt setting = MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Concatenate');
		setting.ConcatenateCharacter__c = '|';
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{ setting });
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('A|B|C', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Concatenate keeps the unique values joined by the configured character');
	}

	static testMethod void testContactConcatenateNonStringFieldIsUntouched() {
		// a Concatenate rule on a non-string field is ignored (rule only applies to string/multiselect)
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Birthdate=Date.newInstance(2000,1,1)),
			new Contact(Id=mergeId, Birthdate=Date.newInstance(1980,1,1))
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','Birthdate','Preserve','Concatenate')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals(Date.newInstance(2000,1,1), (Date) MRG_TestFactory.keptValue(keepId,'Contact','Birthdate'),
			'Concatenate on a non-string field leaves the kept value unchanged');
	}
}
