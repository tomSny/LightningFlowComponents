import { LightningElement, api, track, wire } from 'lwc';


export default class SortingConfiguration extends LightningElement {
   

    @api objectName;
    @api fieldSortingListString; 
    @track fieldSortingList = [];
    get availableFieldList() {
        let availableFieldList = this._fieldList.filter(
            field => {
                let fieldSorting = this.fieldSortingList.find(
                    item => field.name === item.field
                );

                return !fieldSorting;
            }
        );

        return availableFieldList;
    }

    @api get fieldList () {
        return this._fieldList;
    }
    
    set fieldList(value) {
        if(value) {
            this._fieldList = JSON.parse(JSON.stringify(value)); 
        } else {
            this._fieldList = [];
        }
    }

    @track _fieldList = [];
    @track fieldSortingList = [];

    @api selectedFieldListString;

    connectedCallback() {
        if(this.fieldSortingListString){
            this.fieldSortingList = JSON.parse(this.fieldSortingListString);
        } else {
            this.fieldSortingList = [];
        }
        
        if(this._fieldList) {
            let fieldAPINameList = [];
            let fieldSortingList = [];
            this._fieldList.forEach(
                (item, index) => {
                    fieldAPINameList.push(item.name);
                    let fieldSorting = this.fieldSortingList.find(
                            element => {
                                return element.field === item.name
                            }
                    );
                    if(fieldSorting) {
                        fieldSortingList.push(fieldSorting);
                    } else { 
                        fieldSortingList.push({
                            field : item.name,
                            sortingDirection : 'ASC' 
                        });
                    }
                        
                }   
            );
            this.fieldSortingList = fieldSortingList;
                
            this.selectedFieldListString = fieldAPINameList.join(',');
            
        } else {
            this._fieldList = [];
            this.selectedFieldListString = '';
        }
    }
    changeSorting(event) {
        this.fieldSortingList[event.detail.index].sortingDirection = event.detail.sortingDirection;
        this.fieldSortingList[event.detail.index].field = event.detail.field;
        let fieldAPINameList = [];
        
        this.fieldSortingList.forEach(
            (item, index) => {
                if(!event.detail.field && index > event.detail.index) {
                    item.field = '';
                }
            }
        );
        this.fieldSortingList.forEach(
            (item, index) => {
                fieldAPINameList.push(item.field);
            }
        );
        this.selectedFieldListString = fieldAPINameList.join(',');
        this.fieldSortingListString = JSON.stringify(this.fieldSortingList)
    }

    @api validate() {
        let isFieldDuplicate = false;
        let isFieldEmpty = false;
        this.fieldSortingList.forEach(
            (item, index) => {
                for(let i = index; i < this.fieldSortingList.length - 1; i++) {
                    if(item.field && item.field === this.fieldSortingList[i + 1].field) {
                        isFieldDuplicate = true;
                        break;
                    }
                    
                }
                if(!item.field) {
                    isFieldEmpty = true;
                }
            }
        );

        if(isFieldDuplicate) { 
            return { 
                isValid: false, 
                errorMessage: 'Field duplication' 
            }; 
        } else if(isFieldEmpty){
            return { 
                isValid: false, 
                errorMessage: 'Need to fill all fields' 
            };  
        } else { 
            return { isValid: true }; 
        } 
    }

}