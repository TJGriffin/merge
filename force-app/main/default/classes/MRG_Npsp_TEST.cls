/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the optional NPSP integration; the NPSP Callable API is mocked so the tests
* run in orgs with or without NPSP installed
*/
@isTest
public class MRG_Npsp_TEST {

	/*******************************************************************************************************
	* @description records the actions sent to the NPSP Callable API
	*/
	public class CallableMock implements System.Callable {
		public List<String> actions = new List<String>();
		public Object call(String action, Map<String, Object> args) {
			actions.add(action);
			return null;
		}
	}

	/*******************************************************************************************************
	* @description injects a mock NPSP Callable API and returns it
	*/
	public static CallableMock mockNpsp() {
		CallableMock mock = new CallableMock();
		MRG_Npsp_SVC.npspApi = mock;
		return mock;
	}

	static testMethod void testDisableTriggersCallsNpspApi() {
		CallableMock mock = mockNpsp();

		system.assertEquals(true, MRG_Npsp_SVC.isInstalled());
		system.assertEquals(true, MRG_Npsp_SVC.disableTriggers());
		system.assertEquals(new List<String>{ MRG_Npsp_SVC.ACTION_DISABLE_ALL_TRIGGERS }, mock.actions);
	}

	static testMethod void testDisableTriggersWithoutMockMatchesInstallState() {
		// no mock: NPSP is resolved by name, so this passes whether or not NPSP is installed
		Boolean installed = Type.forName('npsp', 'Callable_API') != null;

		system.assertEquals(installed, MRG_Npsp_SVC.isInstalled());
		system.assertEquals(installed, MRG_Npsp_SVC.disableTriggers());
	}
}
