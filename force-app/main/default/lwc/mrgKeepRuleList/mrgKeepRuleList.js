import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepRules from '@salesforce/apex/MRG_KeepRule_CTRL.getRules';
import saveKeepRules from '@salesforce/apex/MRG_KeepRule_CTRL.saveRules';

export default class mrgKeepRuleList extends LightningElement {
    @track cols;
    notificationTitle;
    notificationBody;
    notificationStyle;

    connectedCallback() {
        this.objectType = this.objectType == null ? '' : this.objectType;
        this.disabled = false;
        this.registerErrorListener();
        this.handleSubscribe();

    }
    refresh() {
        this.handleSubscribe();
    }
    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            this.error = error;
            this.handleError();
        });
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