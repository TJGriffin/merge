import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {refreshApex} from '@salesforce/apex';
import getUsers from '@salesforce/apex/MRG_MergeSettings_CTRL.getUsers';
import getProfiles from '@salesforce/apex/MRG_MergeSettings_CTRL.getProfiles';
import getSettings from '@salesforce/apex/MRG_MergeSettings_CTRL.getMergeSetting';
import saveSettings from '@salesforce/apex/MRG_MergeSettings_CTRL.saveMergeSettings';

export default class mrgGlobalSettings extends LightningElement {

    @track settings;
    @track settingsResult;
    @track users;
    @track _users;
    @track profiles;
    @track _profiles;
    @track selectedUsers = [];
    @track selectedProfiles = [];
    @track accountTrigger = false;
    @track accountTriggerDisabled = false;
    @track contactTriggerDisabled = false;
    @track disabledUsers =[];
    @track disabledProfiles = [];
    @track error;
    @track userCols;
    @track profileCols;
    @track hasChanges = false;
    notificationBody;
    notificationStyle;
    notificationTitle;

    get isAccountTriggerDisabled(){
        return this.accountTriggerDisabled;
    }

    get isContactTriggerDisabled(){
        return this.contactTriggerDisabled;
    }

    connectedCallback(){

        this.userCols = [
            {label:'User Name',fieldName:'userName'},
            {label:'First Name',fieldName:'firstName'},
            {label:'Last Name',fieldName:'lastName'},
            {label:'Email',fieldName:'email'},
            {label:'User Profile',fieldName:'profile'},
            {label:'Disabled',fieldName:'disabled'},
            { type: 'action', typeAttributes: { rowActions: this.getRowActions, menuAlignment: 'right' }}
        ];
        this.profileCols= [
            {label:'Profile',fieldName:'name'},
            {label:'Disabled',fieldName:'disabled'},
            { type: 'action', typeAttributes: { rowActions: this.getRowActions, menuAlignment: 'right' }}
        ]
    }

    getRowActions(row, doneCallback){
        const actions = [];
        if(row['disabled']) {
            actions.push({
                'label':'Enable',
                'name':'enable'
            });
        } else {
            actions.push({
                'label':'Disable',
                'name':'disable'
            });        
        }

        doneCallback(actions);
    }
    @wire(getSettings)
    processSettings({error,data}) {
        this.settingsResult = data;
        if(data) {
            this.parseSettings();
        } else {
            this.error=error;
            this.handleError();
        }

    }
    parseSettings(){
        this.settings = JSON.parse(JSON.stringify(this.settingsResult));
        if(this.settings == null)
            console.log('settings is null');
        if(this.settings.hasOwnProperty('disableAccountTrigger'))
            this.accountTriggerDisabled=this.settings.disableAccountTrigger;
        if(this.settings.hasOwnProperty('disableContactTrigger'))
            this.contactTriggerDisabled=this.settings.disableContactTrigger;
        if(this.settings.hasOwnProperty('disabledForUsers'))
            this.disabledUsers = this.settings.disabledForUsers == null ? [] : this.settings.disabledForUsers;
        if(this.settings.hasOwnProperty('disabledForProfiles'))
            this.disabledProfiles = this.settings.disabledForProfiles == null ? [] : this.settings.disabledForProfiles;
        this.parseUsers();
        this.parseProfiles();
    }
    @wire(getUsers)
        processUsers({error,data}){
            if(data) {
                this.users = JSON.parse(JSON.stringify(data));
                this.parseUsers();
            } else {
                this.error=error;
                this.handleError();
            }
        }
    @wire(getProfiles)
        processProfiles({error,data}){
            if(data) {
                this.profiles = JSON.parse(JSON.stringify(data));
                this.parseProfiles();
            } else {
                this.error=error;
                this.handleError();
            }
        }

    parseUsers() {
        console.log('parse users');
        this._users = this._users == null ? null : this._users;
        if(typeof this.users === 'undefined' || typeof this.settings === 'undefined')
            return;
        if(this.users == null || this.settings == null)
            return;
        
        var usrs = [];
        this.users.forEach(user=>{
            user.disabled = this.disabledUsers.includes(user.id);
            usrs.push(user);
        });
        this._users = usrs;
    }
    parseProfiles() {
        this._profiles = this._profiles == null ? null : this._profiles;
        if(typeof this.profiles === 'undefined' || typeof this.settings === 'undefined')
            return;
        if(this.profiles == null || this.settings == null)
            return;
        
        var profs = [];
        this.profiles.forEach(prof=>{
            prof.disabled = this.disabledProfiles.includes(prof.id);
            profs.push(prof);
        });
        this._profiles = profs;
    }
    getSelectedUsers(event){
        this.selectedUsers = event.detail.selectedRows;

    }
    getSelectedProfiles(event) {
        this.selectedProfiles = event.detail.selectedProfiles;
    }

    handleAccountTriggerChange(event){
        console.log(JSON.stringify(event.detail));
        this.accountTriggerDisabled = event.target.checked;
        this.hasChanges=true;
    }

    handleContactTriggerChange(event){
        console.log(JSON.stringify(event.detail));
        this.contactTriggerDisabled = event.target.checked;
        this.hasChanges=true;
    }

    handleUserAction(event){
        this.disabledUsers = this.disabledUsers == null ? [] : this.disabledUsers;
        var action = event.detail.action;
        var userId = event.detail.row.id;
        switch(action.name) {
            case 'disable':
                var disabled = [];
                disabled = this.disabledUsers;
                if(disabled.length == 0 
                    || !disabled.includes(userId))
                    this.disabledUsers.push(userId);
                break;
            case 'enable':
                this.disabledUsers = this.disabledUsers.filter(function(value,index,arr){
                    return value!=userId;
                });
                break;
        }
        console.log('finish processing and parse');
        this.parseUsers();
        this.hasChanges=true;
    }
    handleProfileAction(event){
        var action = event.detail.action;
        var profId = event.detail.row.id;
        switch(action.name) {
            case 'disable':
                if(!this.disabledProfiles.includes(profId))
                    this.disabledProfiles.push(profId);
                break;
            case 'enable':
                this.disabledProfiles= this.disabledProfiles.filter(function(value,index,arr){
                    return value!=profId;
                });
                break;
        }
        this.parseProfiles();

        this.hasChanges=true;
    }
    handleCancel(event) {
        refreshApex(this.settingsResult);
        this.parseSettings();
        this.hasChanges=false;
    }
    handleSave(event) {
        console.log('save called');
        var mergeSettings = {};
        mergeSettings.disableAccountTrigger = this.accountTriggerDisabled;
        mergeSettings.disableContactTrigger = this.contactTriggerDisabled;
        mergeSettings.disabledForUsers = this.disabledUsers;
        mergeSettings.disabledForProfiles = this.disabledProfiles;
        var settingJSON = JSON.stringify(mergeSettings);
        
        saveSettings({mergeSettingJSON:settingJSON})
            .then(result => {
                console.log(JSON.stringify(result));
                this.hasChanges=false;
                this.handleSuccess();
            })
            .catch(error => {
                this.error = error;
            })
    }
    handleSuccess() {
        console.log('handleSuccess called');
        this.notificationTitle = 'Settings Saved';
        this.notificationStyle='success';
        this.notificationBody = 'Settings have been successfully saved.';
        this.showNotification();
        this.refresh();
    }
    handleError() {
        this.notificationTitle = 'An error has occurred';
        this.notificationBody = 'Unknown error';
        this.notificationStyle = 'error';
        if(this.error == null ||
            !this.error.hasOwnProperty('body')) {
                console.log(JSON.stringify(this.error));

        } else if(Array.isArray(this.error.body)) {
            this.notificationBody = this.error.body.map(e => e.message).join(', ');
        } else if(typeof this.error.body.message === 'string') {
            this.notificationBody = this.error.body.message;
        }
        this.showNotification();
    }
    showNotification(){
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.notificationTitle,
                message: this.notificationBody,
                variant: this.notificationStyle
            })
        );
    }   
    
}