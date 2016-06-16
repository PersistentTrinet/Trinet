/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(seeAllData=false)
public class OpportunityRecommendationsCtrlTest implements HttpCalloutMock{ 
	public static Opportunity opp;
	public static User newUser;
	public static Boolean isCreated;
	public static KaybusConfig__c oppchild2config;
	public static Opportunitycompetitor oppcompe;
	public static void prepareTestData(){
		Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
      	newUser = new User(Alias = 'standt', Email='standarduser@testorg.com', 
      					EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
     				 	LocaleSidKey='en_US', ProfileId = p.Id, 
      					TimeZoneSidKey='America/Los_Angeles', UserName='testUser@kaybus.testorg');
      	system.runAs(newUser){ 				
			opp = new Opportunity();
			opp.name = 'Kaybus Test Opp';
			opp.StageName = 'Open';            
            opp.Amount = 0.0;
            opp.StageName = 'Test';
			opp.CloseDate = Date.Today().addDays(10);
			insert opp;
			
			oppcompe = new Opportunitycompetitor();
			oppcompe.CompetitorName = 'Kaybus';
			oppcompe.OpportunityId = opp.id;
			
			if(!KaybusConfig__c.getAll().containsKey('ClientId')){
				KaybusConfig__c clientIdConf = new KaybusConfig__c();
				clientIdConf.Name = 'ClientId';
				clientIdConf.Value__c = 'Dummy';
				insert clientIdConf;
			}
			if(!KaybusConfig__c.getAll().containsKey('ClientSecret')){
				KaybusConfig__c clientSecConf = new KaybusConfig__c();
				clientSecConf.Name = 'ClientSecret';
				clientSecConf.Value__c = 'Dummy';
				insert clientSecConf;
			}
			if(!KaybusConfig__c.getAll().containsKey('Tenant')){
				KaybusConfig__c tenetConfig = new KaybusConfig__c();
				tenetConfig.Name = 'Tenant';	
				tenetConfig.Value__c = 'https://xyz.kaybus.com';
				insert tenetConfig;
			}
			
			KaybusConfig__c oppchild1config1 = new KaybusConfig__c();
			oppchild1config1.Name = 'Opp Child 1';
			oppchild1config1.RelationshipName__c = 'OpportunityLineItem';
			oppchild1config1.Field_Name__c = 'Product2.Name';
			insert oppchild1config1;
			
			oppchild2config = new KaybusConfig__c();
			oppchild2config.Name = 'Opp Child 2';
			oppchild2config.RelationshipName__c = 'Opportunitycompetitors';
			oppchild2config.Field_Name__c = 'CompetitorName,Weaknesses ';
			insert oppchild2config;
			
		 
      	}
      	PermissionSet perSet = new PermissionSet();
      	list<PermissionSet> perSetLst = [Select Id from PermissionSet where name = 'Kaybus_Permission_Set'];
      	if(perSetLst != null && perSetLst.size() > 0){
      		perSet = perSetLst[0];
      	}else{
      		perSet.Name = 'Kaybus_Permission_Set';
			insert perSet;
      	}
		
		PermissionSetAssignment pa = new PermissionSetAssignment();
		list<PermissionSetAssignment> perSetAssignLst = [Select Id from PermissionSetAssignment where PermissionSet.Name = 'Kaybus_Permission_Set' 
														 and AssigneeID = :UserInfo.getUserId()];
		if(perSetAssignLst != null && perSetAssignLst.size() > 0){
      		pa = perSetAssignLst[0];
      	}else{
			pa.AssigneeID = UserInfo.getUserId();
			pa.PermissionSetId = perSet.Id;
			insert pa;
		}
		
      	isCreated = false;
	}
    public static testMethod void myUnitTest(){
        // TO DO: implement unit test
        prepareTestData(); 
        Test.startTest();
        
     	Test.setMock(HttpCalloutMock.class, new OpportunityRecommendationsCtrlTest());
     	
     	isCreated = true;
        ApexPages.StandardController sc = new ApexPages.StandardController(opp);
        OpportunityRecommendationsCtrl recommendation = new OpportunityRecommendationsCtrl(sc);
        
        system.assert(recommendation.allsearches != null);
        system.assertEquals(recommendation.tenantUrl, 'https://xyz.kaybus.com');
        
        recommendation.courseId = 'dummyCourseId';
        isCreated = false;
        recommendation.favouriteItem();
        recommendation.isFavorite = true;
        recommendation.favouriteItem();
        
        isCreated = true;
        recommendation.favouriteItem();
        recommendation.isFavorite = true;
        recommendation.favouriteItem();
        
        recommendation.userOrGrpId = 'userId';
        recommendation.userName = 'test asus';
        recommendation.userType = 'User';
        recommendation.userComment = 'Shared';
        recommendation.shareContent();
        
        list<OpportunityRecommendationsCtrl.UserOrGroupDetail> usersLst = OpportunityRecommendationsCtrl.queryUsers('a');
        
        /* Coverage for Wrapper Classes - Start*/
        OpportunityRecommendationsCtrl.Searches tmpSearch = new OpportunityRecommendationsCtrl.Searches(); 	
        OpportunityRecommendationsCtrl.Downloads down = new OpportunityRecommendationsCtrl.Downloads();
        OpportunityRecommendationsCtrl.Image img = new OpportunityRecommendationsCtrl.Image();
        
        for(OpportunityRecommendationsCtrl.Searches src : recommendation.allSearches){
        	tmpSearch.id = src.id;
			tmpSearch.title = src.title;
			tmpSearch.description = src.description;
			tmpSearch.article_type = src.article_type; 
        	tmpSearch.state = src.state;
			tmpSearch.tags = src.tags;
			tmpSearch.categories = src.categories;
        	tmpSearch.rating = src.rating;
			tmpSearch.publisher_id =src.publisher_id;
			tmpSearch.publisher_name =src.publisher_name; 
        	tmpSearch.published_at =src.published_at;
			tmpSearch.file =src.file;
			tmpSearch.group_names = src.group_names;tmpSearch.rating_count =src.rating_count;
        	tmpSearch.user_rating =  src.user_rating;
			tmpSearch.step_count = src.step_count;
			tmpSearch.enrollment = src.enrollment;
			tmpSearch.created_at = src.created_at;
        	tmpSearch.updated_at = src.updated_at;
			tmpSearch.content_updated_at = src.content_updated_at;
			tmpSearch.is_updated = src.is_updated;
        	tmpSearch.is_content_updated = src.is_content_updated;
			tmpSearch.downloads = src.downloads;
			tmpSearch.editable = src.editable;
        	tmpSearch.allow_sharing = src.allow_sharing;
			tmpSearch.allow_guest_sharing = src.allow_guest_sharing;
			tmpSearch.allow_guest_sharing = src.allow_guest_sharing; 
        	tmpSearch.isFavorited = src.isFavorited;
			tmpSearch.image = src.image;
			
        	for(OpportunityRecommendationsCtrl.Downloads d : src.downloads){
        		down.url = d.url; down.type = d.type; down.format = d.format; down.filename = d.filename;
        	}
        	
        	img.id = src.image.id;
        	img.thumbnails = src.image.thumbnails;
        	img.thumbnails.grid = src.image.thumbnails.grid;
        	
        	tmpSearch.enrollment.id = src.enrollment.id;
        	tmpSearch.enrollment.progress = src.enrollment.progress;
        	tmpSearch.enrollment.state = src.enrollment.state;
        	tmpSearch.enrollment.created_at = src.enrollment.created_at;
        	tmpSearch.enrollment.updated_at = src.enrollment.updated_at;
        	tmpSearch.enrollment.last_viewed_at = src.enrollment.last_viewed_at;
        	tmpSearch.enrollment.percent_complete = src.enrollment.percent_complete;
        	tmpSearch.enrollment.downloaded_but_not_viewed = src.enrollment.downloaded_but_not_viewed;
        	tmpSearch.enrollment.enrollable_id = src.enrollment.enrollable_id;
        	
			tmpSearch.enrollment.progress.last_step = src.enrollment.progress.last_step;
        	tmpSearch.enrollment.progress.percent_complete = src.enrollment.progress.percent_complete;
        	
        	        	
        	tmpSearch.user_rating.id = src.user_rating.id;
        	tmpSearch.user_rating.comment = src.user_rating.comment;
        	tmpSearch.user_rating.created_at = src.user_rating.created_at;
        	tmpSearch.user_rating.mark = src.user_rating.mark;
        	tmpSearch.user_rating.rater_class = src.user_rating.rater_class;
        	tmpSearch.user_rating.rater_id = src.user_rating.rater_id;
        	tmpSearch.user_rating.weight = src.user_rating.weight;
        	
        }
        OpportunityRecommendationsCtrl.SearchResponse srcRep = new OpportunityRecommendationsCtrl.SearchResponse();
		srcRep = recommendation.searchResp; 
		
		OpportunityRecommendationsCtrl.Named_lists nameLst = new OpportunityRecommendationsCtrl.Named_lists();
		OpportunityRecommendationsCtrl.NamedListResponse nrResp = new OpportunityRecommendationsCtrl.NamedListResponse();
		
		OpportunityRecommendationsCtrl.Meta met = new OpportunityRecommendationsCtrl.Meta();
		if(srcRep != null && srcRep.Meta != null){
			met.facets = srcRep.Meta.facets;
			met.pagination = srcRep.Meta.pagination;
			met.highlights = srcRep.Meta.highlights;
			met.search_suggestions = srcRep.Meta.search_suggestions;
			met.relevance_scores = srcRep.Meta.relevance_scores;
			met.experts = srcRep.Meta.experts;
		}
		if(srcRep != null && srcRep.Meta != null && srcRep.Meta.pagination != null){
			OpportunityRecommendationsCtrl.Pagination pagin = new OpportunityRecommendationsCtrl.Pagination();
			pagin.page = srcRep.Meta.pagination.page;
			pagin.total = srcRep.Meta.pagination.page;
			pagin.total_pages = srcRep.Meta.pagination.total_pages;
			pagin.per_page = srcRep.Meta.pagination.per_page;
		}
		OpportunityRecommendationsCtrl.Users usrTmp = new OpportunityRecommendationsCtrl.Users();
		OpportunityRecommendationsCtrl.Groups grpTmp = new OpportunityRecommendationsCtrl.Groups();
		
		for(OpportunityRecommendationsCtrl.UserOrGroupDetail result: usersLst){
			if(result.type == 'User'){
				usrTmp.id = result.id;
				usrTmp.first_name = result.name;
				usrTmp.last_name = result.name;
				usrTmp.email = 'asus@kaybus.test';
			}else{
				grpTmp.id = result.id;
				grpTmp.name = result.name;
			}
		}
		/* Coverage for Wrapper Classes - End*/
        Test.stopTest();
    }
    
    public HTTPResponse respond(HTTPRequest req){   
        HttpResponse res = new HttpResponse();
        String tenantURL = KaybusConfig__c.getAll().containsKey('Tenant') ? KaybusConfig__c.getAll().get('Tenant').Value__c : 'https://xyz.kaybus.com';
        
        system.assertEquals(tenantURL, 'https://xyz.kaybus.com');
        
        if(req.getEndpoint().contains(tenantURL + '/policy/oauth/access_token')){
            String response='{"token_type":"bearer","access_token":"accToken","expires_in":"9600"}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL + '/api/searches')){
            String response='{"searches":[{"id":"dummyCourseId","title":"Dummy Title","description":"Dummy Desc.","article_type":"courses","state":"active","tags":["Newsletter"],"categories":["Newsletter"],"rating":null,"publisher_id":"5493f5499a6bf4b03a000029","publisher_name":"Raghu Srinivasan","published_at":"2015-02-03T11:01:55+00:00","expires_at":null,"group_names":[],"file":"fileUrl","rating_count":0,"user_rating":{"_id":"ratingId","comment":"My Comment","created_at":"2015-05-04T04:41:12Z","mark":4,"rater_class":"User","rater_id":"userId","weight":1},"step_count":0,"enrollment":{"id":"enrolId","progress":{"steps":{},"last_step":null,"percent_complete":0},"state":"viewed","created_at":"2015-05-07T06:04:19Z","updated_at":"2015-05-07T06:15:42Z","last_downloaded_at":"2015-05-07T06:15:42+00:00","last_viewed_at":null,"percent_complete":0,"downloaded_but_not_viewed":true,"enrollable_id":"enrolId"},"created_at":"2015-02-03T11:01:55Z","updated_at":"2015-04-16T09:31:39Z","content_updated_at":"2015-02-03T11:01:55+00:00","is_updated":null,"is_content_updated":null,"downloads":[{"url":"courseUrl","type":"Asset","format":"original"},{"url":"zipURL","type":"Course","format":"zip"}],"editable":false,"allow_sharing":true,"allow_guest_sharing":false,"image":{"id":"imgId","thumbnails":{"grid":"gridURL"}}}],"meta":{"facets":[],"pagination":{"page":1,"total":100,"total_pages":25,"per_page":4},"highlights":[],"search_suggestions":[],"relevance_scores":[],"experts":[]}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL + '/api/named_lists?name=favorites')){
        	String response = '';
        	if(!isCreated){
        		response = '{"named_lists":[]}';
        	}else{
        		response='{"named_lists":[{"id":"nameListId","name":"favorites","list_type":"system","named_list_items":[{"id":"nameListItemId","named_list_id":"nameListId","position":null,"listable_type":"Course","listable_id":"dummyCourseId"}]}]}';
        	}
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL+'/api/named_lists')){
            String response='{"named_list":{"id":"nameListId","name":"favorites","list_type":"system","named_list_items":[]}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        } else if(req.getEndpoint().equals(tenantURL + '/api/named_list_items') && req.getMethod().equals('POST')){
            String response='{"named_list_item":{"id":"nameListItemId2","named_list_id":"nameListId","position":null,"listable_type":"Course","listable_id":"dummyCourseId"}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        }else if(req.getEndpoint().contains(tenantURL + '/api/named_list_items/') && req.getMethod().equals('DELETE')){
            String response='';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(204);
        }else if(req.getEndpoint().contains(tenantURL+'/api/audiences?match=')){
            String response='{"users":[{"id":"userId","first_name":"test","last_name":"asus","email":"asus@kaybus.test"}],"groups":[{"id":"grpId","first_name":"test","last_name":"group","email":"group@kaybus.test"}]}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL+'/api/shares')){
            String response='{"share":{"id":"shareID","shareable_id":"dummyCourseId","shareable_type":"Course","shared_with":[{"id":"userId","type":"User","name":"test+asus"}],"comment":null}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        } 
        
        return res;
    }
}