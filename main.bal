import ballerina/http;
import ballerina/log;

listener http:Listener vaccineStatusListener = new(9002);

service /covid/status on new http:Listener(9000) {

    resource function get countries() returns CovidEntry[] {
        log:printInfo("Get all countries");
        return covidTable.toArray();
    }

    resource function post countries(@http:Payload CovidEntry[] covidEntries)
                                    returns CovidEntry[]|ConflictingIsoCodesError {

        string[] conflictingISOs = from CovidEntry covidEntry in covidEntries
            where covidTable.hasKey(covidEntry.iso_code)
            select covidEntry.iso_code;

        if conflictingISOs.length() > 0 {
            log:printInfo("Conflicting ISO Codes");
            return {
                body: {
                    errmsg: string:'join(" ", "Conflicting ISO Codes:", ...conflictingISOs)
                }
            };
        } else {
            log:printInfo("Adding new countries");
            covidEntries.forEach(covdiEntry => covidTable.add(covdiEntry));
            return covidEntries;
        }
    }

    resource function get countries/[string iso_code]() returns CovidEntry|InvalidIsoCodeError {
        log:printInfo("Get country by ISO Code");
        CovidEntry? covidEntry = covidTable[iso_code];
        if covidEntry is () {
            return {
                body: {
                    errmsg: string `Invalid ISO Code: ${iso_code}`
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

service on vaccineStatusListener {
    resource function get vaccination/status() returns string {
        log:printInfo("Vaccination status");
        return "Vaccination is in progress";
    }
}

service /covid/community on new http:Listener(9003) {
    resource function get status() returns string {
        log:printInfo("Community status");
        return "Community is safe";
    }

    resource function get status/[string iso_code]() returns string {
        log:printInfo("Community status by ISO Code");
        return "Community is safe";
    }
}

public type CovidEntry record {|
    readonly string iso_code;
    string country;
    decimal cases;
    decimal deaths;
    decimal recovered;
    decimal active;
|};

public final table<CovidEntry> key(iso_code) covidTable = table [
    {iso_code: "AFG", country: "Afghanistan", cases: 159303, deaths: 7386, recovered: 146084, active: 5833},
    {iso_code: "SL", country: "Sri Lanka", cases: 598536, deaths: 15243, recovered: 568637, active: 14656},
    {iso_code: "US", country: "USA", cases: 69808350, deaths: 880976, recovered: 43892277, active: 25035097}
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
