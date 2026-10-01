/**
* @author tj@tjgriffin.com
* @group Merge
* @description Service for NPSP household Addresses (npsp__Address__c) around the orphaned household
* merge. NPSP objects and fields are reached only dynamically through the Store, so this package
* compiles and runs in orgs without NPSP installed.
*/
public with sharing class MRG_NpspAddress_SVC {

	public static final String ADDRESS_OBJECT = 'npsp__Address__c';
	public static final String FIELD_HOUSEHOLD = 'npsp__Household_Account__c';
	public static final String FIELD_DEFAULT = 'npsp__Default_Address__c';
	public static final String FIELD_STREET = 'npsp__MailingStreet__c';
	public static final String FIELD_STREET2 = 'npsp__MailingStreet2__c';
	public static final String FIELD_CITY = 'npsp__MailingCity__c';
	public static final String FIELD_STATE = 'npsp__MailingState__c';
	public static final String FIELD_POSTAL_CODE = 'npsp__MailingPostalCode__c';
	public static final String FIELD_COUNTRY = 'npsp__MailingCountry__c';
	public static final String FIELD_SEASONAL_START = 'npsp__Seasonal_Start_Month__c';
	public static final String FIELD_CURRENT_ADDRESS = 'npsp__Current_Address__c';
	public static final String FIELD_ADDRESS_OVERRIDE = 'npsp__is_Address_Override__c';

	/*******************************************************************************************************
	* @description an NPSP Address record detached from the npsp__Address__c type, so the logic runs
	* without NPSP. street is multi-line: street, then a line break and street2 when present.
	*/
	public class Address {
		public Id id;
		public Id accountId;
		public Boolean isDefault = false;
		public Boolean isSeasonal = false;
		public String street;
		public String city;
		public String state;
		public String postalCode;
		public String country;
	}

	/*******************************************************************************************************
	* @description the only code that touches npsp__ objects and fields (dynamically). Tests inject a fake.
	*/
	public virtual class Store {

		/*******************************************************************************************************
		* @description whether npsp__Address__c exists in this org
		* @return Boolean
		*/
		public virtual Boolean isAvailable() {
			return Schema.getGlobalDescribe().containsKey(ADDRESS_OBJECT.toLowerCase());
		}

		/*******************************************************************************************************
		* @description all Address records of the given households
		* @param accountIds the household Account ids
		* @return List<Address>
		*/
		public virtual List<Address> getAddresses(Set<Id> accountIds) {
			List<Address> addresses = new List<Address>();
			String soql = 'SELECT Id, ' + String.join(new List<String>{
				FIELD_HOUSEHOLD, FIELD_DEFAULT, FIELD_STREET, FIELD_STREET2, FIELD_CITY, FIELD_STATE,
				FIELD_POSTAL_CODE, FIELD_COUNTRY, FIELD_SEASONAL_START
			}, ', ') + ' FROM ' + ADDRESS_OBJECT + ' WHERE ' + FIELD_HOUSEHOLD + ' IN :accountIds';
			for(SObject rec : Database.query(soql))
				addresses.add(toAddress(rec));
			return addresses;
		}

		/*******************************************************************************************************
		* @description the given contacts that have npsp__is_Address_Override__c set
		* @param contactIds the contacts to check
		* @return Set<Id>
		*/
		public virtual Set<Id> getAddressOverrideContactIds(Set<Id> contactIds) {
			String soql = 'SELECT Id FROM Contact WHERE Id IN :contactIds AND ' + FIELD_ADDRESS_OVERRIDE + ' = true';
			return new Map<Id, SObject>(Database.query(soql)).keySet();
		}

		/*******************************************************************************************************
		* @description inserts Addresses without an id (setting the new id back on the DTO) and updates only
		* the Default flag of the others
		* @param addresses the Addresses to save
		*/
		public virtual void save(List<Address> addresses) {
			Schema.SObjectType addressType = Schema.getGlobalDescribe().get(ADDRESS_OBJECT.toLowerCase());
			List<SObject> updates = new List<SObject>();
			List<SObject> inserts = new List<SObject>();
			List<Address> inserted = new List<Address>();
			for(Address a : addresses) {
				SObject rec = a.id == null ? toRecord(addressType, a) : addressType.newSObject(a.id);
				rec.put(FIELD_DEFAULT, a.isDefault);
				if(a.id == null) {
					inserts.add(rec);
					inserted.add(a);
				} else {
					updates.add(rec);
				}
			}
			if(!updates.isEmpty())
				update updates;
			if(!inserts.isEmpty())
				insert inserts;
			for(Integer i=0; i<inserts.size(); i++)
				inserted[i].id = inserts[i].Id;
		}

		/*******************************************************************************************************
		* @description sets Contact.npsp__Current_Address__c
		* @param addressIdByContactId the Address id to set per contact
		*/
		public virtual void setCurrentAddresses(Map<Id, Id> addressIdByContactId) {
			List<Contact> contacts = new List<Contact>();
			for(Id contactId : addressIdByContactId.keySet()) {
				Contact c = new Contact(Id=contactId);
				c.put(FIELD_CURRENT_ADDRESS, addressIdByContactId.get(contactId));
				contacts.add(c);
			}
			if(!contacts.isEmpty())
				update contacts;
		}

		private Address toAddress(SObject rec) {
			Address a = new Address();
			a.id = rec.Id;
			a.accountId = (Id) rec.get(FIELD_HOUSEHOLD);
			a.isDefault = rec.get(FIELD_DEFAULT) == true;
			a.isSeasonal = rec.get(FIELD_SEASONAL_START) != null;
			String street = (String) rec.get(FIELD_STREET);
			String street2 = (String) rec.get(FIELD_STREET2);
			a.street = String.isNotBlank(street2) ? (street == null ? '' : street) + '\n' + street2 : street;
			a.city = (String) rec.get(FIELD_CITY);
			a.state = (String) rec.get(FIELD_STATE);
			a.postalCode = (String) rec.get(FIELD_POSTAL_CODE);
			a.country = (String) rec.get(FIELD_COUNTRY);
			return a;
		}

		private SObject toRecord(Schema.SObjectType addressType, Address a) {
			SObject rec = addressType.newSObject();
			String street = a.street == null ? '' : a.street;
			Integer lineBreak = street.indexOf('\n');
			rec.put(FIELD_STREET, lineBreak < 0 ? a.street : street.left(lineBreak).removeEnd('\r'));
			rec.put(FIELD_STREET2, lineBreak < 0 ? null : street.substring(lineBreak + 1));
			rec.put(FIELD_HOUSEHOLD, a.accountId);
			rec.put(FIELD_CITY, a.city);
			rec.put(FIELD_STATE, a.state);
			rec.put(FIELD_POSTAL_CODE, a.postalCode);
			rec.put(FIELD_COUNTRY, a.country);
			return rec;
		}
	}

	/*******************************************************************************************************
	* @description the Address store; tests inject a fake
	*/
	@TestVisible private static Store store {
		get {
			if(store == null)
				store = new Store();
			return store;
		}
		set;
	}

	/*******************************************************************************************************
	* @description unflags every default Address of the given households. Run before the household merge
	* so the merged household is not left with two default Addresses. Does nothing without NPSP.
	* @param accountIds the household Account ids
	*/
	public static void clearDefaults(Set<Id> accountIds) {
		if(accountIds == null || accountIds.isEmpty() || !store.isAvailable())
			return;
		List<Address> changed = new List<Address>();
		for(Address a : store.getAddresses(accountIds)) {
			if(a.isDefault) {
				a.isDefault = false;
				changed.add(a);
			}
		}
		if(!changed.isEmpty())
			store.save(changed);
	}

	/*******************************************************************************************************
	* @description makes each kept contact's mailing address the single default Address of its household,
	* sets it as the contact's current address and copies it to the household billing address. Households
	* with more than one contact, address-override contacts, households with a seasonal Address and blank
	* mailing addresses are left untouched. Does nothing without NPSP.
	* @param contactIds the kept contacts
	*/
	public static void resetDefaults(Set<Id> contactIds) {
		if(contactIds == null || contactIds.isEmpty() || !store.isAvailable())
			return;
		Map<Id, Contact> keptByAccountId = eligibleContacts(contactIds);
		if(keptByAccountId.isEmpty())
			return;
		Map<Id, List<Address>> addressesByAccountId = byAccount(store.getAddresses(keptByAccountId.keySet()));

		List<Address> toSave = new List<Address>();
		Map<Id, Address> defaultByContactId = new Map<Id, Address>();
		List<Account> accounts = new List<Account>();
		for(Id accountId : keptByAccountId.keySet()) {
			List<Address> household = addressesByAccountId.containsKey(accountId)
				? addressesByAccountId.get(accountId) : new List<Address>();
			if(hasSeasonal(household))
				continue;
			Contact kept = keptByAccountId.get(accountId);
			Address match = findMatch(household, kept);
			if(match == null) {
				match = newAddress(kept);
				toSave.add(match);
			} else if(!match.isDefault) {
				toSave.add(match);
			}
			for(Address a : household) {
				if(a !== match && a.isDefault) {
					a.isDefault = false;
					toSave.add(a);
				}
			}
			match.isDefault = true;
			defaultByContactId.put(kept.Id, match);
			accounts.add(billingAddress(kept));
		}
		if(accounts.isEmpty())
			return;
		if(!toSave.isEmpty())
			store.save(toSave);

		Map<Id, Id> addressIdByContactId = new Map<Id, Id>();
		for(Id contactId : defaultByContactId.keySet())
			addressIdByContactId.put(contactId, defaultByContactId.get(contactId).id);
		store.setCurrentAddresses(addressIdByContactId);
		update accounts;
	}

	/*******************************************************************************************************
	* @description the kept contacts that are the only member of their household, have no address override
	* and have a mailing address, keyed by AccountId
	*/
	private static Map<Id, Contact> eligibleContacts(Set<Id> contactIds) {
		Set<Id> accountIds = new Set<Id>();
		for(Contact c : [SELECT AccountId FROM Contact WHERE Id IN :contactIds AND AccountId != null])
			accountIds.add(c.AccountId);

		Map<Id, Contact> contactByAccountId = new Map<Id, Contact>();
		Set<Id> sharedAccountIds = new Set<Id>();
		for(Contact c : [
			SELECT Id, AccountId, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry,
				MailingLatitude, MailingLongitude
			FROM Contact
			WHERE AccountId IN :accountIds
		]) {
			if(contactByAccountId.containsKey(c.AccountId))
				sharedAccountIds.add(c.AccountId);
			contactByAccountId.put(c.AccountId, c);
		}

		Set<Id> overrideContactIds = store.getAddressOverrideContactIds(contactIds);
		Map<Id, Contact> eligible = new Map<Id, Contact>();
		for(Contact c : contactByAccountId.values()) {
			if(!sharedAccountIds.contains(c.AccountId) && !overrideContactIds.contains(c.Id) && !isBlankAddress(c))
				eligible.put(c.AccountId, c);
		}
		return eligible;
	}

	private static Map<Id, List<Address>> byAccount(List<Address> addresses) {
		Map<Id, List<Address>> addressesByAccountId = new Map<Id, List<Address>>();
		for(Address a : addresses) {
			if(!addressesByAccountId.containsKey(a.accountId))
				addressesByAccountId.put(a.accountId, new List<Address>());
			addressesByAccountId.get(a.accountId).add(a);
		}
		return addressesByAccountId;
	}

	private static Boolean hasSeasonal(List<Address> household) {
		for(Address a : household) {
			if(a.isSeasonal)
				return true;
		}
		return false;
	}

	/*******************************************************************************************************
	* @description the household Address matching the contact's mailing address, preferring a default one
	*/
	private static Address findMatch(List<Address> household, Contact c) {
		Address match;
		for(Address a : household) {
			if(matches(a, c) && (match == null || (a.isDefault && !match.isDefault)))
				match = a;
		}
		return match;
	}

	private static Boolean matches(Address a, Contact c) {
		return normalize(a.street) == normalize(c.MailingStreet)
			&& normalize(a.city) == normalize(c.MailingCity)
			&& normalize(a.state) == normalize(c.MailingState)
			&& normalize(a.postalCode) == normalize(c.MailingPostalCode)
			&& normalize(a.country) == normalize(c.MailingCountry);
	}

	private static String normalize(String value) {
		return value == null ? '' : value.toLowerCase().normalizeSpace();
	}

	private static Boolean isBlankAddress(Contact c) {
		return String.isBlank(c.MailingStreet) && String.isBlank(c.MailingCity) && String.isBlank(c.MailingState)
			&& String.isBlank(c.MailingPostalCode) && String.isBlank(c.MailingCountry);
	}

	private static Address newAddress(Contact c) {
		Address a = new Address();
		a.accountId = c.AccountId;
		a.street = c.MailingStreet;
		a.city = c.MailingCity;
		a.state = c.MailingState;
		a.postalCode = c.MailingPostalCode;
		a.country = c.MailingCountry;
		return a;
	}

	private static Account billingAddress(Contact c) {
		return new Account(
			Id = c.AccountId,
			BillingStreet = c.MailingStreet,
			BillingCity = c.MailingCity,
			BillingState = c.MailingState,
			BillingPostalCode = c.MailingPostalCode,
			BillingCountry = c.MailingCountry,
			BillingLatitude = c.MailingLatitude,
			BillingLongitude = c.MailingLongitude
		);
	}
}
