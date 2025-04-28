import ballerina/graphql;
import ballerina/http;
import ballerina/log;

public type CovidEntry record {|
    readonly string isoCode;
    string country;
    int cases?;
    int deaths?;
    int recovered?;
    int active?;
|};

public final table<CovidEntry> key(isoCode) covidEntriesTable = table [
    {isoCode: "AFG", country: "Afghanistan", cases: 159303, deaths: 7386, recovered: 146084, active: 5833},
    {isoCode: "SL", country: "Sri Lanka", cases: 598536, deaths: 15243, recovered: 568637, active: 14656},
    {isoCode: "US", country: "USA", cases: 69808350, deaths: 880976, recovered: 43892277, active: 25035097}
];

public type ConflictingIsoCodesError record {|
    *http:Conflict;
    ErrorMsg body;
|};

public type InvalidIsoCodeError record {|
    *http:NotFound;
    ErrorMsg body;
|};

public type ErrorMsg record {|
    string errmsg;
|};

listener http:Listener vaccineStatusListener = new(9002);

public distinct service class CovidData {
    private final readonly & CovidEntry entryRecord;

    function init(CovidEntry entryRecord) {
        self.entryRecord = entryRecord.cloneReadOnly();
    }

    resource function get isoCode() returns string => self.entryRecord.isoCode;

    resource function get country() returns string => self.entryRecord.country;

    resource function get cases() returns int? => self.entryRecord.cases;

    resource function get deaths() returns int? => self.entryRecord.deaths;

    resource function get recovered() returns int? => self.entryRecord.recovered;

    resource function get active() returns int? => self.entryRecord.active;
}

@graphql:ServiceConfig {
    graphiql: {
        enabled: true
    }
}
service /covid19 on new graphql:Listener(9094) {

    resource function get all() returns CovidData[] {
        log:printInfo("Get all countries");
        return from CovidEntry entry in covidEntriesTable select new (entry);
    }

    resource function get filter(string isoCode) returns CovidData? {
        log:printInfo("Get country by ISO Code");
        if covidEntriesTable.hasKey(isoCode) {
            return new CovidData(covidEntriesTable.get(isoCode));
        }
        return;
    }

    remote function add(CovidEntry entry) returns CovidData {
        log:printInfo("Adding new countries");
        covidEntriesTable.add(entry);
        return new CovidData(entry);
    }
}


service /covid/status on new http:Listener(9000) {

    resource function get countries() returns CovidEntry[] {
        log:printInfo("Get all countries");
        return covidEntriesTable.toArray();
    }

    resource function post countries(@http:Payload CovidEntry[] covidEntries)
                                    returns CovidEntry[]|ConflictingIsoCodesError {

        string[] conflictingISOs = from CovidEntry covidEntry in covidEntries
            where covidEntriesTable.hasKey(covidEntry.isoCode)
            select covidEntry.isoCode;

        if conflictingISOs.length() > 0 {
            log:printInfo("Conflicting ISO Codes");
            return {
                body: {
                    errmsg: string:'join(" ", "Conflicting ISO Codes:", ...conflictingISOs)
                }
            };
        } else {
            log:printInfo("Adding new countries");
            covidEntries.forEach(covdiEntry => covidEntriesTable.add(covdiEntry));
            return covidEntries;
        }
    }

    resource function get countries/[string isoCode]() returns CovidEntry|InvalidIsoCodeError {
        log:printInfo("Get country by ISO Code");
        CovidEntry? covidEntry = covidEntriesTable[isoCode];
        if covidEntry is () {
            return {
                body: {
                    errmsg: string `Invalid ISO Code: ${isoCode}`
                }
            };
        }
        return covidEntry;
    }
}

service / on new http:Listener(9001) {
    resource function get healthz() returns string {
        log:printInfo("Health check");
        return "OK";
    }
}

service on new http:Listener(9097) {
    resource function get healthz() returns string {
        log:printInfo("Health check");
        return "OK";
    }
}

service on vaccineStatusListener {
    resource function get vaccination/status() returns string {
        log:printInfo("Vaccination status");
        return "Vaccination is in progress";
    }
}

service /covid/community/support on new http:Listener(9003) {
    resource function get status() returns string {
        log:printInfo("Community support status");
        return "World is supporting each other";
    }

    resource function get status/[string isoCode]() returns string {
        log:printInfo("Community support status by ISO Code");
        return "Community is under lockdown and aids are being provided";
    }
}


listener http:Listener httpListener = new (9093);

http:Service obj = service object {
    resource function get hello() returns string {
        log:printInfo("Say Hello");
        return "Hello!";
    }
};

function init() returns error? {
    check httpListener.attach(obj);
}
