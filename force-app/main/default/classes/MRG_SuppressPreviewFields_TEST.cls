/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for bulk suppression of merge-preview fields from a comma-delimited list:
* valid fields enqueue a metadata deploy, unknown fields are rejected, and an object is required.
*/
@isTest
private class MRG_SuppressPreviewFields_TEST {

	static testMethod void testSuppressValidFields() {
		Test.startTest();
		// mixed casing + spaces + a duplicate; all resolve to valid Contact fields
		String jobId = MRG_MergeSettings_CTRL.suppressPreviewFields('Contact', 'Phone, email ,MailingStreet, phone');
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId, 'valid fields should enqueue a bulk metadata deploy');
	}

	static testMethod void testSuppressInvalidFieldThrows() {
		Boolean threw = false;
		try {
			MRG_MergeSettings_CTRL.suppressPreviewFields('Contact', 'Phone, Not_A_Field_X');
		} catch(Exception e) {
			threw = true;
		}
		system.assert(threw, 'an unknown field should be rejected before deploying');
	}

	static testMethod void testSuppressRequiresObjectAndFields() {
		Boolean threwNoObject = false;
		try {
			MRG_MergeSettings_CTRL.suppressPreviewFields('', 'Phone');
		} catch(Exception e) {
			threwNoObject = true;
		}
		system.assert(threwNoObject, 'an object is required');

		Boolean threwNoFields = false;
		try {
			MRG_MergeSettings_CTRL.suppressPreviewFields('Contact', '   ');
		} catch(Exception e) {
			threwNoFields = true;
		}
		system.assert(threwNoFields, 'at least one field is required');
	}
}
