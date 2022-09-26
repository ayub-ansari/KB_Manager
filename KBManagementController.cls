public with sharing class KBManagementController{
    
    
    @AuraEnabled(cacheable=true)
    public static Boolean getCurrentUserDetail(){
        List<User> u = [SELECT UserPermissionsKnowledgeUser FROM User WHERE Id=: UserInfo.getUserId() WITH SECURITY_ENFORCED];
        return u.isEmpty()?false:u[0].UserPermissionsKnowledgeUser;
    }
    
    @AuraEnabled//(cacheable=true)
    public static List<Object> getDraftArticleList() {
        String objectname = getKnowledgeObjectAPIname();
        return queryArticles(objectname, 'PublishStatus = \'Draft\' WITH SECURITY_ENFORCED ', null);
        /*
        List<Knowledge__kav> knowledges = new List<Knowledge__kav>();
        for(Sobject k: queryArticles('PublishStatus = \'Draft\'')){
            k.put('Summary', '');
            //k.CreatedById = k.CreatedBy.Name;
            for(Object c: k.getDataCategorySelections) k.Summary += c.DataCategoryName+', ';
            if(String.isNotBlank(k.Summary)) k.Summary = k.Summary.removeEnd(', ');
            knowledges.add(k);
        }
        return knowledges;
        */
    }
    
    @AuraEnabled//(cacheable=true)
    public static List<Object> getPublishedArticleList() {
        String objectname = getKnowledgeObjectAPIname();
        Set<String> knowledgeIds = new Set<String>();
        for(SObject art: Database.query('SELECT KnowledgeArticleId FROM '+objectname+ ' WHERE PublishStatus = \'Draft\' WITH SECURITY_ENFORCED LIMIT 20000')){
            knowledgeIds.add((String)art.get('KnowledgeArticleId'));
        }
        //Map<String, SObject> draftArticles = [SELECT Id FROM ];
        
        List<SObject> allPublishedArticles = queryArticles(objectname, 'PublishStatus = \'Online\' AND KnowledgeArticleId NOT IN: knowledgeIds WITH SECURITY_ENFORCED ', knowledgeIds);
        /*for([SELECT FROM Knowledge__kav WHERE ]){
        
        }*/
        return allPublishedArticles;
        //return [SELECT Title, Summary, PublishStatus, CreatedDate, CreatedBy.Name, KnowledgeArticleId FROM Knowledge__kav WHERE PublishStatus = 'Online' WITH SECURITY_ENFORCED];
    }
    
    @AuraEnabled
    public static String publishSelectedArticles(List<SObject> rows){
        system.debug(rows);
        try{
            Boolean isKnowledgeUser = getCurrentUserDetail();
            if(isKnowledgeUser){
                publishArticles(rows);
            }
        }catch(Exception e){return e.getMessage();}
        return 'SUCCESS';
    }
    
    @AuraEnabled
    public static String draftSelectedArticles(List<SObject> rows){
        system.debug(rows);
        try{
            Boolean isKnowledgeUser = getCurrentUserDetail();
            if(isKnowledgeUser){
                draftArticles(rows);
            }
        }catch(Exception e){return e.getMessage();}
        return 'SUCCESS';
    }
    
    //done security part
    @auraEnabled 
    public static String updateArticlesChannel(List<Sobject> rows, List<string> selectedChannels){
        if(!rows.isEmpty()){
            if(rows[0].Id.getSObjectType().getDescribe().isUpdateable()){
                //if (Schema.sObjectType.Knowledge.fields.IsVisibleInPkb.isUpdateable()) {
                for(SObject k: rows){
                    if(selectedChannels.contains('Guest')) k.put('IsVisibleInPkb', true);
                    if(selectedChannels.contains('Partner')) k.put('IsVisibleInPrm', true);
                    if(selectedChannels.contains('Customer')) k.put('IsVisibleInCsp', true);
                }
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, rows);
               
                update securityDecision.getRecords(); // Doesn’t update AnnualRevenue field
                return 'SUCCESS';
            }
        }else {
            return 'You do not have permission to update.';
        }
        return '';
    }
    
    @auraEnabled
    public static List<SObject> filteredArticles(String whereClause){
        if(String.isBlank(whereClause)) return null;
        whereClause = whereClause.removeEnd(' AND ');
        whereClause  += ' WITH SECURITY_ENFORCED ';
        List<Sobject> k = new List<Sobject>();
        system.debug(whereClause);
        String objectname = getKnowledgeObjectAPIname();
        k = queryArticles(objectname, whereClause, null);
        
        return k;
    } 
    
    @auraEnabled 
    public static String performAllAction(String actionType, List<String> selectedChannels){
        String OBJECTname = getKnowledgeObjectAPIname();
        String query = 'SELECT KnowledgeArticleId FROM '+OBJECTname + ' WHERE ';
        if(actionType == 'Publish'){
            query += 'PublishStatus = \'Online\' WITH SECURITY_ENFORCED ';
        }else if(actionType == 'Draft'){
            query += 'PublishStatus = \'Draft\' WITH SECURITY_ENFORCED ';
        }
        Id batchInstanceId = Database.executeBatch(new KBMassActionProcessor(actionType, query), 50); 
        return batchInstanceId;
    }
    
    public static List<SObject> queryArticles(String OBJECTname, String WHERECLUASE, Set<String> knowledgeIds){
        KBManagerConfiguration__mdt kbField = KBManagerConfiguration__mdt.getInstance('KnowledgeFields');
        return Database.query(kbField.LongValue__c+ ' FROM '+OBJECTname+' WHERE '+WHERECLUASE);
            
    }
    
    public static String getKnowledgeObjectAPIname(){
        return [SELECT QualifiedApiName FROM EntityDefinition WHERE KeyPrefix= 'ka0' WITH SECURITY_ENFORCED LIMIT 1].QualifiedApiName ;
    }
    
    public static void draftArticles(List<SObject> rows){    
        for(SObject k: rows){
            system.debug((Id)k.get('KnowledgeArticleId')+'_______________________');
            KbManagement.PublishingService.editOnlineArticle((Id)k.get('KnowledgeArticleId'), false);//don't unpublish current version
        }
    }
    public static void publishArticles(List<SObject> rows){    
        for(SObject k: rows){
            KbManagement.PublishingService.publishArticle((Id)k.get('KnowledgeArticleId'), false);
        } 
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> knowledgeBaseFields (){
        List<OptionWrapper> options = new List<OptionWrapper>();
        String objectName = getKnowledgeObjectAPIname();
        
        Map<String, Schema.SObjectField> m = Schema.describeSObjects(new List<String>{objectName})[0].fields.getMap();
        for(String fd : m.keySet()){
            Schema.DescribeFieldResult dfr = m.get(fd).getDescribe();
            String label = String.valueOf(dfr.getLabel());
            options.add(new OptionWrapper(label, label));
        }    
        
        return options;          
    }
    
    public class OptionWrapper {
        @AuraEnabled
        public String label {get; set;}
        @AuraEnabled
        public String value {get; set;}

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
}