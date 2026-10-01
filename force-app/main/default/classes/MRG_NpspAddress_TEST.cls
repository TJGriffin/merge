/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the NPSP household Address service; the Address store is faked so the tests
* run in orgs with or without NPSP installed
*/
@isTest
public class MRG_NpspAddress_TEST {

	private static Integer idCounter = 0;

	/*******************************************************************************************************
	* @description an in-memory Address store
	*/
	public class FakeStore extends MRG_NpspAddress_SVC.Store {
		public Boolean available = true;
		public List<MRG_NpspAddress_SVC.Address> addresses = new List<MRG_NpspAddress_SVC.Address>();
		public Set<Id> overrideContactIds = new Set<Id>();
		public Map<Id, Id> currentAddressByContactId = new Map<Id, Id>();
		public Integer saveCalls = 0;

		/*******************************************************************************************************
		* @description adds an Address with a fabricated Id to the store and returns it
		*/
		public MRG_NpspAddress_SVC.Address add(Id accountId, String street, Boolean isDefault) {
			MRG_NpspAddress_SVC.Address a = new MRG_NpspAddress_SVC.Address();
			a.id = fakeId();
			a.accountId = accountId;
			a.street = street;
			a.isDefault = isDefault;
			addresses.add(a);
			return a;
		}

		public override Boolean isAvailable() {
			return available;
		}

		public override List<MRG_NpspAddress_SVC.Address> getAddresses(Set<Id> accountIds) {
			List<MRG_NpspAddress_SVC.Address> found = new List<MRG_NpspAddress_SVC.Address>();
			for(MRG_NpspAddress_SVC.Address a : addresses) {
				if(accountIds.contains(a.accountId))
					found.add(a);
			}
			return found;
		}

		public override Set<Id> getAddressOverrideContactIds(Set<Id> contactIds) {
			Set<Id> found = new Set<Id>(contactIds);
			found.retainAll(overrideContactIds);
			return found;
		}

		public override void save(List<MRG_NpspAddress_SVC.Address> toSave) {
			saveCalls++;
			for(MRG_NpspAddress_SVC.Address a : toSave) {
				if(a.id == null) {
					a.id = fakeId();
					addresses.add(a);
				}
			}
		}

		public override void setCurrentAddresses(Map<Id, Id> addressIdByContactId) {
			currentAddressByContactId.putAll(addressIdByContactId);
		}
	}

	/*******************************************************************************************************
	* @description injects a FakeStore into the service and returns it
	*/
	public static FakeStore mockStore() {
		FakeStore fake = new FakeStore();
		MRG_NpspAddress_SVC.store = fake;
		return fake;
	}

	private static Id fakeId() {
		idCounter++;
		return Id.valueOf('001' + String.valueOf(idCounter).leftPad(12, '0'));
	}

	private static Contact contact(Id accountId, String street, String city, String postalCode) {
		// unique names and allowSave so org duplicate rules do not block a second household member
		idCounter++;
		Contact c = new Contact(FirstName='Test', LastName='Address' + idCounter, AccountId=accountId,
			MailingStreet=street, MailingCity=city, MailingPostalCode=postalCode);
		Database.DMLOptions dml = new Database.DMLOptions();
		dml.duplicateRuleHeader.allowSave = true;
		Database.insert(c, dml);
		return [SELECT Id, AccountId, MailingStreet, MailingCity, MailingPostalCode FROM Contact WHERE Id=:c.Id];
	}

	private static Account account(Id accountId) {
		return [SELECT BillingStreet, BillingCity, BillingPostalCode FROM Account WHERE Id=:accountId];
	}

	private static void assertUntouched(FakeStore fake, Id accountId, MRG_NpspAddress_SVC.Address original) {
		system.assertEquals(0, fake.saveCalls);
		system.assertEquals(true, original.isDefault);
		system.assertEquals(true, fake.currentAddressByContactId.isEmpty());
		system.assertEquals(null, account(accountId).BillingStreet);
	}

	static testMethod void testClearDefaultsUnflagsGivenAccountsOnly() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address a1 = fake.add(accs[0].Id, '1 Main St', true);
		MRG_NpspAddress_SVC.Address a2 = fake.add(accs[0].Id, '2 Main St', false);
		MRG_NpspAddress_SVC.Address b1 = fake.add(accs[1].Id, '3 Main St', true);

		MRG_NpspAddress_SVC.clearDefaults(new Set<Id>{ accs[0].Id });

		system.assertEquals(false, a1.isDefault);
		system.assertEquals(false, a2.isDefault);
		system.assertEquals(true, b1.isDefault);
		system.assertEquals(1, fake.saveCalls);
	}

	static testMethod void testClearDefaultsNoOp() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address a1 = fake.add(accs[0].Id, '1 Main St', true);
		fake.add(accs[1].Id, '2 Main St', false);

		MRG_NpspAddress_SVC.clearDefaults(null);
		MRG_NpspAddress_SVC.clearDefaults(new Set<Id>());
		MRG_NpspAddress_SVC.clearDefaults(new Set<Id>{ accs[1].Id });
		fake.available = false;
		MRG_NpspAddress_SVC.clearDefaults(new Set<Id>{ accs[0].Id });

		system.assertEquals(true, a1.isDefault);
		system.assertEquals(0, fake.saveCalls);
	}

	static testMethod void testResetDefaultsFlagsMatchingAddress() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '1 Main St\r\nApt 2', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);
		MRG_NpspAddress_SVC.Address match = fake.add(acc.Id, '1 MAIN ST\nApt 2', false);
		match.city = 'boston';
		match.postalCode = '02101';

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		system.assertEquals(true, match.isDefault);
		system.assertEquals(false, other.isDefault);
		system.assertEquals(2, fake.addresses.size());
		system.assertEquals(1, fake.saveCalls);
		system.assertEquals(match.id, fake.currentAddressByContactId.get(c.Id));
		Account result = account(acc.Id);
		system.assertEquals(c.MailingStreet, result.BillingStreet);
		system.assertEquals('Boston', result.BillingCity);
		system.assertEquals('02101', result.BillingPostalCode);
	}

	static testMethod void testResetDefaultsCreatesAddress() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave\nUnit 3', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		system.assertEquals(2, fake.addresses.size());
		MRG_NpspAddress_SVC.Address created = fake.addresses[1];
		system.assertNotEquals(null, created.id);
		system.assertEquals(true, created.isDefault);
		system.assertEquals(acc.Id, created.accountId);
		system.assertEquals(c.MailingStreet, created.street);
		system.assert(created.street.contains('\n'), 'multi-line street is preserved');
		system.assertEquals('Boston', created.city);
		system.assertEquals(false, other.isDefault);
		system.assertEquals(created.id, fake.currentAddressByContactId.get(c.Id));
		system.assertEquals(c.MailingStreet, account(acc.Id).BillingStreet);
	}

	static testMethod void testResetDefaultsSkipsMultiMemberHousehold() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave', 'Boston', '02101');
		contact(acc.Id, '6 Oak Ave', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		assertUntouched(fake, acc.Id, other);
	}

	static testMethod void testResetDefaultsSkipsAddressOverride() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);
		fake.overrideContactIds.add(c.Id);

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		assertUntouched(fake, acc.Id, other);
	}

	static testMethod void testResetDefaultsSkipsSeasonalHousehold() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);
		fake.add(acc.Id, '7 Beach Rd', false).isSeasonal = true;

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		assertUntouched(fake, acc.Id, other);
	}

	static testMethod void testResetDefaultsSkipsBlankMailingAddress() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, null, null, null);
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		assertUntouched(fake, acc.Id, other);
	}

	static testMethod void testResetDefaultsSkipsWhenUnavailable() {
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave', 'Boston', '02101');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address other = fake.add(acc.Id, '9 Elm St', true);
		fake.available = false;

		MRG_NpspAddress_SVC.resetDefaults(null);
		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>());
		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });

		assertUntouched(fake, acc.Id, other);
	}

	static testMethod void testResetDefaultsBulkHouseholds() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		Contact c1 = contact(accs[0].Id, '1 Main St', 'Boston', '02101');
		Contact c2 = contact(accs[1].Id, '2 Main St', 'Salem', '01970');
		FakeStore fake = mockStore();
		MRG_NpspAddress_SVC.Address match = fake.add(accs[0].Id, '1 main st', false);
		match.city = 'Boston';
		match.postalCode = '02101';
		MRG_NpspAddress_SVC.Address old1 = fake.add(accs[0].Id, '9 Elm St', true);
		MRG_NpspAddress_SVC.Address old2 = fake.add(accs[1].Id, '8 Elm St', true);

		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c1.Id, c2.Id });

		system.assertEquals(1, fake.saveCalls);
		system.assertEquals(4, fake.addresses.size());
		MRG_NpspAddress_SVC.Address created = fake.addresses[3];
		system.assertEquals(accs[1].Id, created.accountId);
		system.assertEquals(true, created.isDefault);
		system.assertEquals(true, match.isDefault);
		system.assertEquals(false, old1.isDefault);
		system.assertEquals(false, old2.isDefault);
		system.assertEquals(match.id, fake.currentAddressByContactId.get(c1.Id));
		system.assertEquals(created.id, fake.currentAddressByContactId.get(c2.Id));
		system.assertEquals('Boston', account(accs[0].Id).BillingCity);
		system.assertEquals('Salem', account(accs[1].Id).BillingCity);
	}

	static testMethod void testDefaultStoreMatchesInstallState() {
		// no fake: the store resolves npsp__Address__c at runtime, so this passes with or without NPSP
		Boolean available = Schema.getGlobalDescribe().containsKey('npsp__address__c');
		Account acc = MRG_TestFactory.accounts(1)[0];
		Contact c = contact(acc.Id, '5 Oak Ave', 'Boston', '02101');

		MRG_NpspAddress_SVC.Store realStore = new MRG_NpspAddress_SVC.Store();
		system.assertEquals(available, realStore.isAvailable());
		// empty saves touch no npsp__ field, so they are safe either way
		realStore.save(new List<MRG_NpspAddress_SVC.Address>());
		realStore.setCurrentAddresses(new Map<Id, Id>());
		MRG_NpspAddress_SVC.clearDefaults(new Set<Id>{ acc.Id });
		MRG_NpspAddress_SVC.resetDefaults(new Set<Id>{ c.Id });
		if(!available)
			system.assertEquals(null, account(acc.Id).BillingStreet);
	}
}
