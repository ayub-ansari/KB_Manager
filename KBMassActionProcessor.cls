public with sharing class KBMassActionProcessor implements Database.Batchable<sObject>{
    String q;
    String actionType;
    public KBMassActionProcessor(String actionType, String query){
        this.q = query;
        this.actionType = actionType;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(q);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope){
        if(actionType == 'Draft'){
            KBManagementController.publishArticles(scope);
        }else{
            KBManagementController.draftArticles(scope);
        }
    }
    
    public void finish(Database.BatchableContext BC){
    }

}