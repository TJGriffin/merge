import { LightningElement, api, track } from 'lwc';
import doRunScan from '@salesforce/apex/MRG_BatchControl_CTRL.runScan';
import doRunMerge from '@salesforce/apex/MRG_BatchControl_CTRL.runAutoMerge';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DupeListControls extends LightningElement {

    notificationTitle;
    notificationBody;
    notificationStyle;
    @track error;
    @track showSpinner;

    handleScanClick(){
        doRunScan()
        .then(result=>{
            this.notificationTitle = 'In Process';
            this.notificationBody = 'The duplicate scan has begun';
            this.notificationStyle = 'success';
            this.showNotification();
        })
        .catch(error=>{
            this.error = error;
            this.handleError();
        });
    }

    handleMergeClick(){
        doRunMerge()
        .then(result=>{
            this.notificationTitle = 'In Process';
            this.notificationBody = 'The merge process for auto merge records has begun';
            this.notificationStyle = 'success';
            this.showNotification();
        })
        .catch(error=>{
            this.error = error;
            this.handleError();
        });
    }

    handleError() {
        this.showSpinner=false;
        this.notificationTitle = 'An error has occurred';
        this.notificationBody = 'Unknown error';
        this.notificationStyle = 'error';
        if(typeof this.error === undefined || this.error == null)
            this.error = {};
        if(!this.error.hasOwnProperty('body'))
            this.error.body ={'message':this.notificationBody};
        if(Array.isArray(this.error.body)) {
            this.notificationBody = this.error.body.map(e => e.message).join(', ');
        } else if(this.error.hasOwnProperty('body')
            && this.error.body.hasOwnProperty('message')
            && typeof this.error.body.message === 'string') {
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