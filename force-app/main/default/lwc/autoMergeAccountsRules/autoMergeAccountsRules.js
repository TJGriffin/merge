import { LightningElement, track, wire } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRules from '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getRules';
import getObjectFields from '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getObjectFields';
import getOperators from '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getOperators';
import getAggregators from '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getAggregators';
import saveRules from '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.saveRules';

export default class AutoMergeAccountsRules extends LightningElement {
    @track objectType = '';
    @track rules = [];
    @track fieldOptions = [];
    @track operatorOptions = [];
    @track aggregatorOptions = [];
    fieldTypeByName = {};

    objectOptions = [
        { label: 'Select an Object', value: '' },
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' }
    ];

    channelName = '/event/MergeRecordSave__e';
    notificationTitle;
    notificationBody;
    notificationStyle;

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();
    }

    @wire(getOperators)
    wiredOperators({ data }) { if (data) { this.operatorOptions = data; } }

    @wire(getAggregators)
    wiredAggregators({ data }) { if (data) { this.aggregatorOptions = data; } }

    get hasObject() {
        return this.objectType !== '' && this.objectType != null;
    }

    handleObjectChange(event) {
        this.objectType = event.detail.value;
        this.rules = [];
        if (this.hasObject) {
            this.loadFields();
            this.loadRules();
        }
    }

    loadFields() {
        getObjectFields({ objectType: this.objectType })
            .then((result) => {
                this.fieldOptions = result.map((f) => ({ label: f.label, value: f.name }));
                const map = {};
                result.forEach((f) => { map[f.name] = f.type; });
                this.fieldTypeByName = map;
                this.rules = this.decorate(this.rules);
            })
            .catch((error) => this.handleError(error));
    }

    loadRules() {
        getRules({ objectType: this.objectType })
            .then((result) => {
                this.rules = this.decorate(JSON.parse(JSON.stringify(result)));
            })
            .catch((error) => this.handleError(error));
    }

    decorate(rules) {
        return (rules || []).map((rule, ri) => {
            rule.uiKey = 'ama-' + ri + '-' + Date.now();
            rule.ruleIndex = ri;
            rule.conditions = (rule.conditions || []).map((c, ci) => this.decorateCondition(c, ri, ci));
            return rule;
        });
    }

    decorateCondition(condition, ri, ci) {
        condition.uiKey = 'cond-' + ri + '-' + ci;
        condition.ruleIndex = ri;
        condition.conditionIndex = ci;
        condition.aggregator = condition.aggregator || 'all';
        // value/operator only apply to all/any; differ/same compare the field across records
        condition.usesValue = condition.aggregator === 'all' || condition.aggregator === 'any';
        const type = this.fieldTypeByName[condition.fieldName];
        condition.inputType = this.inputTypeForFieldType(type);
        condition.isCheckbox = condition.usesValue && condition.inputType === 'checkbox';
        condition.isValueInput = condition.usesValue && !condition.isCheckbox;
        condition.checked = condition.isCheckbox && condition.value === 'true';
        return condition;
    }

    inputTypeForFieldType(fieldType) {
        switch (fieldType) {
            case 'BOOLEAN': return 'checkbox';
            case 'DATE': return 'date';
            case 'DATETIME': return 'datetime';
            case 'DOUBLE':
            case 'CURRENCY':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT': return 'number';
            default: return 'text';
        }
    }

    addRule() {
        const rule = {
            id: null,
            label: this.objectType + ' Auto Merge Accounts ' + (this.rules.length + 1),
            objectName: this.objectType,
            autoMerge: false,
            filterLogic: '',
            conditions: []
        };
        this.rules = this.decorate([...this.rules, rule]);
    }

    removeRule(event) {
        const idx = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules.splice(idx, 1);
        this.rules = this.decorate(rules);
    }

    handleLabelChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].label = event.target.value;
    }

    handleAutoMergeChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].autoMerge = event.target.checked;
    }

    handleLogicChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].filterLogic = event.target.value;
    }

    addCondition(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules[ri].conditions = [...rules[ri].conditions, { fieldName: '', operator: 'equals', value: '', aggregator: 'all' }];
        this.rules = this.decorate(rules);
    }

    removeCondition(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions.splice(ci, 1);
        this.rules = this.decorate(rules);
    }

    handleConditionFieldChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions[ci].fieldName = event.detail.value;
        this.rules = this.decorate(rules);
    }

    handleConditionAggregatorChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions[ci].aggregator = event.detail.value;
        this.rules = this.decorate(rules);
    }

    handleConditionOperatorChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        this.rules[ri].conditions[ci].operator = event.detail.value;
    }

    handleConditionValueChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const cond = this.rules[ri].conditions[ci];
        cond.value = cond.isCheckbox ? String(event.target.checked) : event.target.value;
    }

    handleSave() {
        const payload = this.rules.map((rule) => ({
            id: rule.id,
            label: rule.label,
            objectName: rule.objectName,
            autoMerge: rule.autoMerge,
            filterLogic: rule.filterLogic,
            conditions: (rule.conditions || []).map((c) => ({
                fieldName: c.fieldName,
                operator: c.operator,
                value: c.value,
                aggregator: c.aggregator
            }))
        }));
        saveRules({ jsonData: JSON.stringify(payload) })
            .then(() => {})
            .catch((error) => this.handleError(error));
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            if (response && response.data && response.data.payload &&
                response.data.payload.IsSuccess__c === true) {
                this.handleSuccess();
            }
        };
        subscribe(this.channelName, -1, messageCallback).then((response) => {
            this.subscription = response;
        });
    }

    registerErrorListener() {
        onError((error) => this.handleError(error));
    }

    handleSuccess() {
        this.notificationTitle = 'Auto-Merge Accounts Rules Saved';
        this.notificationStyle = 'success';
        this.notificationBody = '';
        this.showNotification();
        if (this.hasObject) {
            this.loadRules();
        }
    }

    handleError(error) {
        this.notificationTitle = 'An error has occurred';
        this.notificationStyle = 'error';
        this.notificationBody = 'Unknown error';
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                this.notificationBody = error.body.map((e) => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                this.notificationBody = error.body.message;
            }
        }
        this.showNotification();
    }

    showNotification() {
        this.dispatchEvent(new ShowToastEvent({
            title: this.notificationTitle,
            message: this.notificationBody,
            variant: this.notificationStyle
        }));
    }
}
