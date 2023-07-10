/**
* @author tj@tjgriffin.com
* @date 2023
* @group Duplicate
* @description service for managing the batch jobs
*/
public with sharing class MRG_BatchControl_SVC {

	/***
	* @description cron frequencies
	*/	
    public Map<String, String> jobScheduleFrequencies {
        get {
            return new Map<String, String>{
                'hourly' => '0 0 * * * ?',
                'nightly' => '0 0 2 * * ?',
                'weekly' => '0 0 2 * * 1'
            };
        }
        set;
    }


	/***
	* @description default scan job name
	*/	
    public static String duplicateScanJobName {
        get {
            if(duplicateScanJobName == null){
                MergeControlSettings__c settings = MergeControlSettings__c.getOrgDefaults();
                duplicateScanJobName = String.isBlank(settings.DuplicateScanJobName__c) ? 'Scheduled Duplicate Scan' : settings.DuplicateScanJobName__c;
            }
            return duplicateScanJobName;
        }
        set;
    }

	/***
	* @description default merge job name
	*/	
    public static String duplicateMergeJobName {
        get {
            if(duplicateMergeJobName== null){
                MergeControlSettings__c settings = MergeControlSettings__c.getOrgDefaults();
                duplicateMergeJobName = String.isBlank(settings.DuplicateMergeJobName__c) ? 'Scheduled Duplicate Merge' : settings.DuplicateMergeJobName__c;
            }
            return duplicateMergeJobName;
        }
        set;
    }

	/*******************************************************************************************************
	* @description gets the list of jobs currently scheduled
	* @return List<dupeRule>
	*/	
    public List<scheduledJob> getScheduledJobs() {
        Map<String, scheduledJob> scheduledJobsByName = new Map<String, scheduledJob>();
        Set<String> scheduledJobNames = new Set<String>{duplicateScanJobName,duplicateMergeJobName};

        for(CronTrigger ct:
            [SELECT 
                Id,
                CronDetail.Name,
                NextFireTime
                FROM
                CronTrigger
                WHERE CronDetail.Name IN:scheduledJobNames]){
                    scheduledJob sj = new scheduledJob(ct);
                    scheduledJobsByName.put(sj.jobName,sj);
        }
        for(String jobName:scheduledJobNames){
            if(!scheduledJobsByName.containsKey(jobName)){
                scheduledJob sj = new scheduledJob();
                sj.jobName = jobName;
                sj.isActive = false;
                scheduledJobsByName.put(sj.jobName,sj);
            }
        }

        return scheduledJobsByName.values();
    }


	/*******************************************************************************************************
	* @description wrapper class for scheduled jobs
	*/	
	public class scheduledJob {
		@auraEnabled
		public String jobId {get;set;}

		@auraEnabled 
		public Datetime nextRunTime {get;set;}

		@auraEnabled 
		public String jobName {get;set;}

		@auraEnabled
		public Boolean isActive {get;set;}
        
        public scheduledJob(){

        }

		public scheduledJob(CronTrigger ct){
			this.jobId = ct.Id;
			this.jobName = ct.CronDetail.Name;
			this.nextRunTime = ct.NextFireTime;
			this.isActive = true;
		}
	}
}