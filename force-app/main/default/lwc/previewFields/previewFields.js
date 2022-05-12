import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFieldSettings from '@salesforce/apex/MRG_MergeSettings_CTRL.getAllPreviewFields';
import savePreviewFields from '@salesforce/apex/MRG_MergeSettings_CTRL.savePreviewFieldsSettings';

export default class previewFields extends LightningElement {
    @track cols;
    set results(value) {
        value = value === undefined || value == null ? [] : value;
        this.rows = [];
        this.rows = JSON.parse(JSON.stringify(value));
    }
    get results(){
        return this.rows;
    }
    @track rows;
    @track hasFields = false;
    @track hidden;
    @track draftValues;
    @track objectType;
    @track wireComplete=false;
    @track hasChanged = false;
    @track isNew =false;
    resultValue;
    objectOptions = [{label:'Filter by Object', value:''},{label:'Account',value:'Account'},{label:'Contact', value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;
    modalLabel='Edit Preview Field';
    // platform event
    channelName = '/event/MergeRecordSave__e';
    isSubscribeDisabled = false;
    isUnsubscribeDisabled = !this.isSubscribeDisabled;
    subscription={};
    handleChannelNAme(event) {
        this.channelName = event.target.value;
    }
    
    connectedCallback() {
        this.objectType = this.objectType == null ? '' : this.objectType;
        this.disabled = false;
        this.registerErrorListener();
        this.handleSubscribe();

    }
    refresh() {
        this.handleSubscribe();
    }
    fetchData(){

        getFieldSettings({objectType:this.objectType})
            .then(result=>{
                this.results=JSON.parse(JSON.stringify(result));
            })
            .catch(error=>{
                this.error=error;
                this.handleError();
            })
    }
    handleSubscribe(){
        // Callback invoked whenever a new event message is received
        const messageCallback = function(response) {
            console.log('New message received: ', JSON.stringify(response));
            if(response.hasOwnProperty('data')
                && response.data.hasOwnProperty('payload')
                && response.data.payload.hasOwnProperty('IsSuccess__c')) {
                    console.log('has success property');
                    if(response.data.payload.IsSuccess__c == true) {
                        console.log('is success');
                        this.handleSuccess();
                }
            }
            

        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback.bind(this)).then(response => {
            // Response contains the subscription information on subscribe call
            console.log('Subscription request sent to: ', JSON.stringify(response.channel));
            this.subscription = response;
        });
    }
    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            this.error = error;
            this.handleError();
        });
    }
    @wire(getFieldSettings, {objectType:'$objectType'})
        getRowData(result) {
            this.results = [];
            this.resultValue = result;
            if(result.data) {
                this.results=result.data;
                this.error=undefined;
                this.wireComplete = true;
            } else if(result.error){
                this.rows=undefined;
                this.error=result.error;
                this.handleError();
            }
        }
    handleNotify(event){
        this.isNew=false;
        this.selectedRecord = this.selectedRecord === undefined || this.selectedRecord == null ? {} : this.selectedRecord;
        var action = event.detail.actionType; 

        if(action!='cancel'
            && event.detail != null) {
            this.hasChanged=true;
            this.selectedRecord = JSON.parse(JSON.stringify(event.detail.recordValue));
            this.selectedRecord.name = this.selectedRecord.name == null || this.selectedRecord.name.includes('TEMP') ? this.selectedRecord.fieldName+''+this.selectedRecord.objectName : this.selectedRecord.name;
            var rows = [];
            var isnew = true;
            this.rows.forEach(row=>{
                if(row.name == this.selectedRecord.name) {
                    isnew=false;
                    rows.push(this.selectedRecord);
                } else if(!row.name.includes('TEMP')) {
                    rows.push(row);
                }
            });
            if(isnew)
                rows.push(this.selectedRecord);
            this.results = rows;
        }
    }

    addRow(event){
        this.isNew=true;
        this.selectedRecord = {};
        this.selectedRecord.name='TEMP';
        this.selectedRecord.objectName = this.objectType;
        this.selectedRecord.hidden = true;
        this.results = [...this.rows,this.selectedRecord];
    }

    handleSave() {
        this.hasChanged=false;
        console.log('handle save');
        console.log(JSON.stringify(this.rows));
        savePreviewFields({
            jsonData:JSON.stringify(this.rows)
        })
        .then(()=>{

        })
        .catch((error)=>{
            this.error=error;
            this.handleError();
        })
    }

    handleSuccess() {
        console.log('handleSuccess called');
        this.notificationTitle = 'Record Saved';
        this.notificationStyle='success';
        this.showNotification();
        this.refresh();
    }
    handleError() {
        this.notificationTitle = 'An error has occurred';
        this.notificationBody = 'Unknown error';
        this.notificationStyle = 'error';
        if(Array.isArray(this.error.body)) {
            this.notificationBody = this.error.body.map(e => e.message).join(', ');
        } else if(typeof this.error.body.message === 'string') {
            this.notificationBody = this.error.body.message;
        }
        this.showNotification();
    }
    handleObjectFilterChange(event){
        this.objectType = event.detail.value;
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