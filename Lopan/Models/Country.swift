//
//  Country.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//

import Foundation

/// Region model with cities
struct CountryRegion: Codable, Hashable {
    let name: String
    let cities: [String]

    init(name: String, cities: [String] = []) {
        self.name = name
        self.cities = cities
    }
}

/// Represents a country with localization and contact information
struct Country: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let flag: String  // Emoji flag
    let dialCode: String
    let regions: [String]  // Administrative regions/provinces (simple string list)
    let detailedRegions: [CountryRegion]?  // Detailed regions with cities (optional)

    init(id: String, name: String, flag: String, dialCode: String, regions: [String] = [], detailedRegions: [CountryRegion]? = nil) {
        self.id = id
        self.name = name
        self.flag = flag
        self.dialCode = dialCode
        self.regions = regions
        self.detailedRegions = detailedRegions
    }
}

// MARK: - Global Country Database

extension Country {
    // MARK: - Africa (Major Markets with Detailed Cities)

    static let nigeria = Country(
        id: "NG",
        name: "Nigeria",
        flag: "🇳🇬",
        dialCode: "+234",
        regions: [
            // South West
            "Lagos State", "Oyo State", "Ogun State", "Osun State", "Ondo State", "Ekiti State",
            // South East
            "Anambra State", "Abia State", "Enugu State", "Imo State", "Ebonyi State",
            // South South
            "Rivers State", "Delta State", "Akwa Ibom State", "Cross River State", "Bayelsa State", "Edo State",
            // North Central
            "FCT", "Kaduna State", "Niger State", "Plateau State", "Benue State", "Kogi State", "Nasarawa State", "Kwara State",
            // North West
            "Kano State", "Katsina State", "Sokoto State", "Kebbi State", "Zamfara State", "Jigawa State",
            // North East
            "Borno State", "Adamawa State", "Bauchi State", "Gombe State", "Taraba State", "Yobe State"
        ],
        detailedRegions: [
            // South West
            CountryRegion(name: "Lagos State", cities: ["Lagos Island", "Lagos Mainland", "Ikeja", "Lekki", "Victoria Island", "Ikoyi", "Surulere", "Yaba", "Apapa", "Epe", "Badagry"]),
            CountryRegion(name: "Oyo State", cities: ["Ibadan", "Ogbomosho", "Oyo", "Iseyin"]),
            CountryRegion(name: "Ogun State", cities: ["Abeokuta", "Ijebu Ode", "Sagamu", "Ota"]),
            CountryRegion(name: "Osun State", cities: ["Osogbo", "Ile-Ife", "Ilesha", "Ede"]),
            CountryRegion(name: "Ondo State", cities: ["Akure", "Ondo", "Owo"]),
            CountryRegion(name: "Ekiti State", cities: ["Ado-Ekiti", "Ikere-Ekiti", "Efon-Alaaye"]),
            // South East
            CountryRegion(name: "Anambra State", cities: ["Onitsha", "Awka", "Nnewi", "Ekwulobia"]),
            CountryRegion(name: "Abia State", cities: ["Aba", "Umuahia", "Arochukwu"]),
            CountryRegion(name: "Enugu State", cities: ["Enugu", "Nsukka", "Oji River"]),
            CountryRegion(name: "Imo State", cities: ["Owerri", "Orlu", "Okigwe"]),
            CountryRegion(name: "Ebonyi State", cities: ["Abakaliki", "Afikpo", "Onueke"]),
            // South South
            CountryRegion(name: "Rivers State", cities: ["Port Harcourt", "Obio-Akpor", "Eleme", "Okrika"]),
            CountryRegion(name: "Delta State", cities: ["Asaba", "Warri", "Sapele", "Ughelli"]),
            CountryRegion(name: "Akwa Ibom State", cities: ["Uyo", "Eket", "Ikot Ekpene"]),
            CountryRegion(name: "Cross River State", cities: ["Calabar", "Ugep", "Ikom"]),
            CountryRegion(name: "Bayelsa State", cities: ["Yenagoa", "Brass", "Sagbama"]),
            CountryRegion(name: "Edo State", cities: ["Benin City", "Auchi", "Ekpoma"]),
            // North Central
            CountryRegion(name: "FCT", cities: ["Abuja", "Gwagwalada", "Kuje", "Bwari"]),
            CountryRegion(name: "Kaduna State", cities: ["Kaduna", "Zaria", "Kafanchan"]),
            CountryRegion(name: "Niger State", cities: ["Minna", "Bida", "Kontagora"]),
            CountryRegion(name: "Plateau State", cities: ["Jos", "Bukuru", "Pankshin"]),
            CountryRegion(name: "Benue State", cities: ["Makurdi", "Gboko", "Otukpo"]),
            CountryRegion(name: "Kogi State", cities: ["Lokoja", "Okene", "Idah"]),
            CountryRegion(name: "Nasarawa State", cities: ["Lafia", "Keffi", "Akwanga"]),
            CountryRegion(name: "Kwara State", cities: ["Ilorin", "Offa", "Omu-Aran"]),
            // North West
            CountryRegion(name: "Kano State", cities: ["Kano", "Wudil", "Bichi"]),
            CountryRegion(name: "Katsina State", cities: ["Katsina", "Daura", "Funtua"]),
            CountryRegion(name: "Sokoto State", cities: ["Sokoto", "Tambuwal", "Gwadabawa"]),
            CountryRegion(name: "Kebbi State", cities: ["Birnin Kebbi", "Argungu", "Zuru"]),
            CountryRegion(name: "Zamfara State", cities: ["Gusau", "Kaura Namoda", "Anka"]),
            CountryRegion(name: "Jigawa State", cities: ["Dutse", "Hadejia", "Gumel"]),
            // North East
            CountryRegion(name: "Borno State", cities: ["Maiduguri", "Biu", "Bama"]),
            CountryRegion(name: "Adamawa State", cities: ["Yola", "Mubi", "Jimeta"]),
            CountryRegion(name: "Bauchi State", cities: ["Bauchi", "Azare", "Misau"]),
            CountryRegion(name: "Gombe State", cities: ["Gombe", "Kumo", "Deba"]),
            CountryRegion(name: "Taraba State", cities: ["Jalingo", "Wukari", "Bali"]),
            CountryRegion(name: "Yobe State", cities: ["Damaturu", "Potiskum", "Gashua"])
        ]
    )

    static let southAfrica = Country(
        id: "ZA",
        name: "South Africa",
        flag: "🇿🇦",
        dialCode: "+27",
        regions: ["Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"],
        detailedRegions: [
            CountryRegion(name: "Gauteng", cities: ["Johannesburg", "Pretoria", "Soweto"]),
            CountryRegion(name: "Western Cape", cities: ["Cape Town"]),
            CountryRegion(name: "KwaZulu-Natal", cities: ["Durban"]),
            CountryRegion(name: "Eastern Cape", cities: ["Port Elizabeth"])
        ]
    )

    static let egypt = Country(
        id: "EG",
        name: "Egypt",
        flag: "🇪🇬",
        dialCode: "+20",
        regions: ["Cairo", "Alexandria", "Giza", "Qalyubia"]
    )

    static let kenya = Country(
        id: "KE",
        name: "Kenya",
        flag: "🇰🇪",
        dialCode: "+254",
        regions: ["Nairobi", "Mombasa", "Kisumu", "Nakuru"]
    )

    static let ghana = Country(
        id: "GH",
        name: "Ghana",
        flag: "🇬🇭",
        dialCode: "+233",
        regions: ["Greater Accra", "Ashanti", "Western", "Eastern"]
    )

    // MARK: - Asia (Major Markets with Detailed Cities)

    static let china = Country(
        id: "CN",
        name: "China",
        flag: "🇨🇳",
        dialCode: "+86",
        regions: [
            // Municipalities
            "Beijing", "Shanghai", "Tianjin", "Chongqing",
            // Provinces - East
            "Guangdong", "Zhejiang", "Jiangsu", "Fujian", "Shandong", "Anhui", "Jiangxi",
            // Provinces - North
            "Hebei", "Shanxi", "Inner Mongolia", "Liaoning", "Jilin", "Heilongjiang",
            // Provinces - Central
            "Henan", "Hubei", "Hunan",
            // Provinces - South
            "Guangxi", "Hainan",
            // Provinces - Southwest
            "Sichuan", "Guizhou", "Yunnan", "Tibet",
            // Provinces - Northwest
            "Shaanxi", "Gansu", "Qinghai", "Ningxia", "Xinjiang",
            // Special Administrative Regions
            "Hong Kong", "Macau"
        ],
        detailedRegions: [
            // Municipalities
            CountryRegion(name: "Beijing", cities: ["Beijing", "Chaoyang", "Haidian", "Dongcheng"]),
            CountryRegion(name: "Shanghai", cities: ["Shanghai", "Pudong", "Huangpu", "Xuhui"]),
            CountryRegion(name: "Tianjin", cities: ["Tianjin", "Binhai", "Hexi"]),
            CountryRegion(name: "Chongqing", cities: ["Chongqing", "Yuzhong", "Jiangbei"]),
            // East China
            CountryRegion(name: "Guangdong", cities: ["Guangzhou", "Shenzhen", "Dongguan", "Foshan", "Zhuhai", "Shantou", "Zhongshan"]),
            CountryRegion(name: "Zhejiang", cities: ["Hangzhou", "Ningbo", "Wenzhou", "Jinhua", "Shaoxing"]),
            CountryRegion(name: "Jiangsu", cities: ["Nanjing", "Suzhou", "Wuxi", "Changzhou", "Xuzhou"]),
            CountryRegion(name: "Fujian", cities: ["Fuzhou", "Xiamen", "Quanzhou", "Zhangzhou"]),
            CountryRegion(name: "Shandong", cities: ["Jinan", "Qingdao", "Yantai", "Weifang"]),
            CountryRegion(name: "Anhui", cities: ["Hefei", "Wuhu", "Bengbu"]),
            CountryRegion(name: "Jiangxi", cities: ["Nanchang", "Ganzhou", "Jiujiang"]),
            // North China
            CountryRegion(name: "Hebei", cities: ["Shijiazhuang", "Tangshan", "Baoding"]),
            CountryRegion(name: "Shanxi", cities: ["Taiyuan", "Datong", "Yangquan"]),
            CountryRegion(name: "Inner Mongolia", cities: ["Hohhot", "Baotou", "Ordos"]),
            CountryRegion(name: "Liaoning", cities: ["Shenyang", "Dalian", "Anshan"]),
            CountryRegion(name: "Jilin", cities: ["Changchun", "Jilin", "Siping"]),
            CountryRegion(name: "Heilongjiang", cities: ["Harbin", "Qiqihar", "Daqing"]),
            // Central China
            CountryRegion(name: "Henan", cities: ["Zhengzhou", "Luoyang", "Kaifeng"]),
            CountryRegion(name: "Hubei", cities: ["Wuhan", "Yichang", "Xiangyang"]),
            CountryRegion(name: "Hunan", cities: ["Changsha", "Zhuzhou", "Xiangtan"]),
            // South China
            CountryRegion(name: "Guangxi", cities: ["Nanning", "Liuzhou", "Guilin"]),
            CountryRegion(name: "Hainan", cities: ["Haikou", "Sanya", "Sansha"]),
            // Southwest
            CountryRegion(name: "Sichuan", cities: ["Chengdu", "Mianyang", "Deyang"]),
            CountryRegion(name: "Guizhou", cities: ["Guiyang", "Zunyi", "Anshun"]),
            CountryRegion(name: "Yunnan", cities: ["Kunming", "Qujing", "Yuxi"]),
            CountryRegion(name: "Tibet", cities: ["Lhasa", "Shigatse", "Chamdo"]),
            // Northwest
            CountryRegion(name: "Shaanxi", cities: ["Xi'an", "Baoji", "Xianyang"]),
            CountryRegion(name: "Gansu", cities: ["Lanzhou", "Tianshui", "Baiyin"]),
            CountryRegion(name: "Qinghai", cities: ["Xining", "Haidong", "Golmud"]),
            CountryRegion(name: "Ningxia", cities: ["Yinchuan", "Shizuishan", "Wuzhong"]),
            CountryRegion(name: "Xinjiang", cities: ["Urumqi", "Kashgar", "Turpan"]),
            // Special Administrative Regions
            CountryRegion(name: "Hong Kong", cities: ["Hong Kong Island", "Kowloon", "New Territories"]),
            CountryRegion(name: "Macau", cities: ["Macau Peninsula", "Taipa", "Coloane"])
        ]
    )

    static let india = Country(
        id: "IN",
        name: "India",
        flag: "🇮🇳",
        dialCode: "+91",
        regions: [
            // North
            "Delhi", "Punjab", "Haryana", "Himachal Pradesh", "Jammu and Kashmir", "Uttarakhand", "Chandigarh",
            // Central
            "Uttar Pradesh", "Madhya Pradesh", "Chhattisgarh",
            // East
            "West Bengal", "Bihar", "Jharkhand", "Odisha",
            // West
            "Maharashtra", "Gujarat", "Rajasthan", "Goa",
            // South
            "Karnataka", "Tamil Nadu", "Kerala", "Andhra Pradesh", "Telangana", "Puducherry",
            // Northeast
            "Assam", "Meghalaya", "Manipur", "Nagaland", "Tripura", "Arunachal Pradesh", "Mizoram", "Sikkim"
        ],
        detailedRegions: [
            // North
            CountryRegion(name: "Delhi", cities: ["New Delhi", "Delhi", "Dwarka", "Rohini"]),
            CountryRegion(name: "Punjab", cities: ["Chandigarh", "Ludhiana", "Amritsar", "Jalandhar"]),
            CountryRegion(name: "Haryana", cities: ["Gurugram", "Faridabad", "Panipat", "Ambala"]),
            CountryRegion(name: "Himachal Pradesh", cities: ["Shimla", "Dharamshala", "Manali"]),
            CountryRegion(name: "Jammu and Kashmir", cities: ["Srinagar", "Jammu", "Anantnag"]),
            CountryRegion(name: "Uttarakhand", cities: ["Dehradun", "Haridwar", "Roorkee"]),
            CountryRegion(name: "Chandigarh", cities: ["Chandigarh"]),
            // Central
            CountryRegion(name: "Uttar Pradesh", cities: ["Lucknow", "Kanpur", "Agra", "Varanasi", "Noida"]),
            CountryRegion(name: "Madhya Pradesh", cities: ["Bhopal", "Indore", "Gwalior", "Jabalpur"]),
            CountryRegion(name: "Chhattisgarh", cities: ["Raipur", "Bilaspur", "Durg"]),
            // East
            CountryRegion(name: "West Bengal", cities: ["Kolkata", "Howrah", "Durgapur", "Siliguri"]),
            CountryRegion(name: "Bihar", cities: ["Patna", "Gaya", "Bhagalpur"]),
            CountryRegion(name: "Jharkhand", cities: ["Ranchi", "Jamshedpur", "Dhanbad"]),
            CountryRegion(name: "Odisha", cities: ["Bhubaneswar", "Cuttack", "Rourkela"]),
            // West
            CountryRegion(name: "Maharashtra", cities: ["Mumbai", "Pune", "Nagpur", "Thane", "Nashik"]),
            CountryRegion(name: "Gujarat", cities: ["Ahmedabad", "Surat", "Vadodara", "Rajkot"]),
            CountryRegion(name: "Rajasthan", cities: ["Jaipur", "Jodhpur", "Udaipur", "Kota"]),
            CountryRegion(name: "Goa", cities: ["Panaji", "Vasco da Gama", "Margao"]),
            // South
            CountryRegion(name: "Karnataka", cities: ["Bangalore", "Mysore", "Mangalore", "Hubli"]),
            CountryRegion(name: "Tamil Nadu", cities: ["Chennai", "Coimbatore", "Madurai", "Tiruchirappalli"]),
            CountryRegion(name: "Kerala", cities: ["Thiruvananthapuram", "Kochi", "Kozhikode", "Thrissur"]),
            CountryRegion(name: "Andhra Pradesh", cities: ["Visakhapatnam", "Vijayawada", "Guntur"]),
            CountryRegion(name: "Telangana", cities: ["Hyderabad", "Warangal", "Nizamabad"]),
            CountryRegion(name: "Puducherry", cities: ["Puducherry"]),
            // Northeast
            CountryRegion(name: "Assam", cities: ["Guwahati", "Silchar", "Dibrugarh"]),
            CountryRegion(name: "Meghalaya", cities: ["Shillong", "Tura"]),
            CountryRegion(name: "Manipur", cities: ["Imphal"]),
            CountryRegion(name: "Nagaland", cities: ["Kohima", "Dimapur"]),
            CountryRegion(name: "Tripura", cities: ["Agartala"]),
            CountryRegion(name: "Arunachal Pradesh", cities: ["Itanagar"]),
            CountryRegion(name: "Mizoram", cities: ["Aizawl"]),
            CountryRegion(name: "Sikkim", cities: ["Gangtok"])
        ]
    )

    static let japan = Country(
        id: "JP",
        name: "Japan",
        flag: "🇯🇵",
        dialCode: "+81",
        regions: ["Tokyo", "Osaka", "Kyoto", "Kanagawa", "Hokkaido"],
        detailedRegions: [
            CountryRegion(name: "Tokyo", cities: ["Tokyo", "Shibuya", "Shinjuku"]),
            CountryRegion(name: "Osaka", cities: ["Osaka"]),
            CountryRegion(name: "Kyoto", cities: ["Kyoto"]),
            CountryRegion(name: "Kanagawa", cities: ["Yokohama"]),
            CountryRegion(name: "Hokkaido", cities: ["Sapporo"])
        ]
    )

    static let southKorea = Country(
        id: "KR",
        name: "South Korea",
        flag: "🇰🇷",
        dialCode: "+82",
        regions: ["Seoul", "Busan", "Incheon", "Daegu"],
        detailedRegions: [
            CountryRegion(name: "Seoul", cities: ["Seoul", "Gangnam", "Hongdae"]),
            CountryRegion(name: "Busan", cities: ["Busan"]),
            CountryRegion(name: "Incheon", cities: ["Incheon"]),
            CountryRegion(name: "Daegu", cities: ["Daegu"])
        ]
    )

    static let singapore = Country(
        id: "SG",
        name: "Singapore",
        flag: "🇸🇬",
        dialCode: "+65",
        regions: ["Central", "East", "North", "West"],
        detailedRegions: [
            CountryRegion(name: "Central", cities: ["Singapore City"])
        ]
    )

    static let thailand = Country(
        id: "TH",
        name: "Thailand",
        flag: "🇹🇭",
        dialCode: "+66",
        regions: ["Bangkok", "Chiang Mai", "Phuket", "Pattaya"]
    )

    static let vietnam = Country(
        id: "VN",
        name: "Vietnam",
        flag: "🇻🇳",
        dialCode: "+84",
        regions: ["Hanoi", "Ho Chi Minh City", "Da Nang", "Haiphong"]
    )

    static let indonesia = Country(
        id: "ID",
        name: "Indonesia",
        flag: "🇮🇩",
        dialCode: "+62",
        regions: ["Jakarta", "Bali", "Surabaya", "Bandung"]
    )

    static let malaysia = Country(
        id: "MY",
        name: "Malaysia",
        flag: "🇲🇾",
        dialCode: "+60",
        regions: ["Kuala Lumpur", "Selangor", "Penang", "Johor"]
    )

    static let philippines = Country(
        id: "PH",
        name: "Philippines",
        flag: "🇵🇭",
        dialCode: "+63",
        regions: ["Metro Manila", "Cebu", "Davao", "Quezon City"]
    )

    static let pakistan = Country(
        id: "PK",
        name: "Pakistan",
        flag: "🇵🇰",
        dialCode: "+92",
        regions: ["Punjab", "Sindh", "Khyber Pakhtunkhwa", "Balochistan"]
    )

    static let bangladesh = Country(
        id: "BD",
        name: "Bangladesh",
        flag: "🇧🇩",
        dialCode: "+880",
        regions: ["Dhaka", "Chittagong", "Khulna", "Rajshahi"]
    )

    static let uae = Country(
        id: "AE",
        name: "United Arab Emirates",
        flag: "🇦🇪",
        dialCode: "+971",
        regions: ["Dubai", "Abu Dhabi", "Sharjah", "Ajman"]
    )

    static let saudiArabia = Country(
        id: "SA",
        name: "Saudi Arabia",
        flag: "🇸🇦",
        dialCode: "+966",
        regions: ["Riyadh", "Makkah", "Eastern Province", "Madinah"]
    )

    static let israel = Country(
        id: "IL",
        name: "Israel",
        flag: "🇮🇱",
        dialCode: "+972",
        regions: ["Tel Aviv", "Jerusalem", "Haifa", "Beersheba"]
    )

    static let turkey = Country(
        id: "TR",
        name: "Turkey",
        flag: "🇹🇷",
        dialCode: "+90",
        regions: ["Istanbul", "Ankara", "Izmir", "Antalya"]
    )

    // MARK: - Europe (Major Markets with Detailed Cities)

    static let uk = Country(
        id: "GB",
        name: "United Kingdom",
        flag: "🇬🇧",
        dialCode: "+44",
        regions: ["England", "Scotland", "Wales", "Northern Ireland"],
        detailedRegions: [
            CountryRegion(name: "England", cities: ["London", "Manchester", "Birmingham", "Liverpool", "Leeds", "Bristol"]),
            CountryRegion(name: "Scotland", cities: ["Edinburgh", "Glasgow", "Aberdeen"]),
            CountryRegion(name: "Wales", cities: ["Cardiff", "Swansea"]),
            CountryRegion(name: "Northern Ireland", cities: ["Belfast", "Derry"])
        ]
    )

    static let germany = Country(
        id: "DE",
        name: "Germany",
        flag: "🇩🇪",
        dialCode: "+49",
        regions: ["Berlin", "Bavaria", "Hamburg", "Hesse", "North Rhine-Westphalia"],
        detailedRegions: [
            CountryRegion(name: "Berlin", cities: ["Berlin"]),
            CountryRegion(name: "Bavaria", cities: ["Munich", "Nuremberg"]),
            CountryRegion(name: "Hamburg", cities: ["Hamburg"]),
            CountryRegion(name: "Hesse", cities: ["Frankfurt", "Wiesbaden"]),
            CountryRegion(name: "North Rhine-Westphalia", cities: ["Cologne", "Dusseldorf", "Dortmund"])
        ]
    )

    static let france = Country(
        id: "FR",
        name: "France",
        flag: "🇫🇷",
        dialCode: "+33",
        regions: ["Île-de-France", "Provence-Alpes-Côte d'Azur", "Auvergne-Rhône-Alpes", "Occitanie"],
        detailedRegions: [
            CountryRegion(name: "Île-de-France", cities: ["Paris", "Versailles"]),
            CountryRegion(name: "Provence-Alpes-Côte d'Azur", cities: ["Marseille", "Nice", "Toulon"]),
            CountryRegion(name: "Auvergne-Rhône-Alpes", cities: ["Lyon", "Grenoble"]),
            CountryRegion(name: "Occitanie", cities: ["Toulouse", "Montpellier"])
        ]
    )

    static let italy = Country(
        id: "IT",
        name: "Italy",
        flag: "🇮🇹",
        dialCode: "+39",
        regions: ["Lazio", "Lombardy", "Campania", "Sicily"],
        detailedRegions: [
            CountryRegion(name: "Lazio", cities: ["Rome"]),
            CountryRegion(name: "Lombardy", cities: ["Milan", "Bergamo"]),
            CountryRegion(name: "Campania", cities: ["Naples"]),
            CountryRegion(name: "Sicily", cities: ["Palermo", "Catania"])
        ]
    )

    static let spain = Country(
        id: "ES",
        name: "Spain",
        flag: "🇪🇸",
        dialCode: "+34",
        regions: ["Madrid", "Catalonia", "Andalusia", "Valencia"],
        detailedRegions: [
            CountryRegion(name: "Madrid", cities: ["Madrid"]),
            CountryRegion(name: "Catalonia", cities: ["Barcelona", "Tarragona"]),
            CountryRegion(name: "Andalusia", cities: ["Seville", "Malaga"]),
            CountryRegion(name: "Valencia", cities: ["Valencia"])
        ]
    )

    static let netherlands = Country(
        id: "NL",
        name: "Netherlands",
        flag: "🇳🇱",
        dialCode: "+31",
        regions: ["North Holland", "South Holland", "Utrecht", "North Brabant"],
        detailedRegions: [
            CountryRegion(name: "North Holland", cities: ["Amsterdam", "Haarlem"]),
            CountryRegion(name: "South Holland", cities: ["Rotterdam", "The Hague"]),
            CountryRegion(name: "Utrecht", cities: ["Utrecht"]),
            CountryRegion(name: "North Brabant", cities: ["Eindhoven"])
        ]
    )

    static let belgium = Country(
        id: "BE",
        name: "Belgium",
        flag: "🇧🇪",
        dialCode: "+32",
        regions: ["Brussels", "Flanders", "Wallonia"]
    )

    static let switzerland = Country(
        id: "CH",
        name: "Switzerland",
        flag: "🇨🇭",
        dialCode: "+41",
        regions: ["Zurich", "Geneva", "Bern", "Basel"]
    )

    static let austria = Country(
        id: "AT",
        name: "Austria",
        flag: "🇦🇹",
        dialCode: "+43",
        regions: ["Vienna", "Salzburg", "Tyrol", "Styria"]
    )

    static let sweden = Country(
        id: "SE",
        name: "Sweden",
        flag: "🇸🇪",
        dialCode: "+46",
        regions: ["Stockholm", "Västra Götaland", "Skåne"]
    )

    static let norway = Country(
        id: "NO",
        name: "Norway",
        flag: "🇳🇴",
        dialCode: "+47",
        regions: ["Oslo", "Bergen", "Trondheim", "Stavanger"]
    )

    static let denmark = Country(
        id: "DK",
        name: "Denmark",
        flag: "🇩🇰",
        dialCode: "+45",
        regions: ["Capital Region", "Central Denmark", "Southern Denmark"]
    )

    static let finland = Country(
        id: "FI",
        name: "Finland",
        flag: "🇫🇮",
        dialCode: "+358",
        regions: ["Uusimaa", "Pirkanmaa", "Varsinais-Suomi"]
    )

    static let poland = Country(
        id: "PL",
        name: "Poland",
        flag: "🇵🇱",
        dialCode: "+48",
        regions: ["Masovian", "Lesser Poland", "Greater Poland", "Silesian"]
    )

    static let czechia = Country(
        id: "CZ",
        name: "Czech Republic",
        flag: "🇨🇿",
        dialCode: "+420",
        regions: ["Prague", "South Moravian", "Moravian-Silesian"]
    )

    static let portugal = Country(
        id: "PT",
        name: "Portugal",
        flag: "🇵🇹",
        dialCode: "+351",
        regions: ["Lisbon", "Porto", "Algarve"]
    )

    static let greece = Country(
        id: "GR",
        name: "Greece",
        flag: "🇬🇷",
        dialCode: "+30",
        regions: ["Attica", "Central Macedonia", "Crete"]
    )

    static let russia = Country(
        id: "RU",
        name: "Russia",
        flag: "🇷🇺",
        dialCode: "+7",
        regions: ["Moscow", "Saint Petersburg", "Novosibirsk", "Yekaterinburg"]
    )

    static let ukraine = Country(
        id: "UA",
        name: "Ukraine",
        flag: "🇺🇦",
        dialCode: "+380",
        regions: ["Kyiv", "Kharkiv", "Odessa", "Dnipro"]
    )

    static let ireland = Country(
        id: "IE",
        name: "Ireland",
        flag: "🇮🇪",
        dialCode: "+353",
        regions: ["Leinster", "Munster", "Connacht", "Ulster"]
    )

    // MARK: - Americas (Major Markets with Detailed Cities)

    static let usa = Country(
        id: "US",
        name: "United States",
        flag: "🇺🇸",
        dialCode: "+1",
        regions: [
            // West
            "California", "Washington", "Oregon", "Nevada", "Arizona", "Utah", "Colorado", "Idaho", "Montana", "Wyoming", "Alaska", "Hawaii",
            // Midwest
            "Illinois", "Ohio", "Michigan", "Indiana", "Wisconsin", "Minnesota", "Iowa", "Missouri", "Kansas", "Nebraska", "South Dakota", "North Dakota",
            // South
            "Texas", "Florida", "Georgia", "North Carolina", "Virginia", "Tennessee", "Louisiana", "Alabama", "Mississippi", "Arkansas", "South Carolina", "Kentucky", "Oklahoma", "West Virginia", "Maryland", "Delaware",
            // Northeast
            "New York", "Pennsylvania", "New Jersey", "Massachusetts", "Connecticut", "Rhode Island", "New Hampshire", "Vermont", "Maine"
        ],
        detailedRegions: [
            // West Coast
            CountryRegion(name: "California", cities: ["Los Angeles", "San Francisco", "San Diego", "San Jose", "Sacramento", "Oakland", "Fresno", "Long Beach"]),
            CountryRegion(name: "Washington", cities: ["Seattle", "Spokane", "Tacoma", "Vancouver", "Bellevue"]),
            CountryRegion(name: "Oregon", cities: ["Portland", "Eugene", "Salem", "Gresham"]),
            CountryRegion(name: "Nevada", cities: ["Las Vegas", "Reno", "Henderson", "Carson City"]),
            CountryRegion(name: "Arizona", cities: ["Phoenix", "Tucson", "Mesa", "Scottsdale"]),
            CountryRegion(name: "Utah", cities: ["Salt Lake City", "Provo", "West Valley City"]),
            CountryRegion(name: "Colorado", cities: ["Denver", "Colorado Springs", "Aurora", "Fort Collins"]),
            CountryRegion(name: "Idaho", cities: ["Boise", "Nampa", "Meridian"]),
            CountryRegion(name: "Montana", cities: ["Billings", "Missoula", "Great Falls"]),
            CountryRegion(name: "Wyoming", cities: ["Cheyenne", "Casper", "Laramie"]),
            CountryRegion(name: "Alaska", cities: ["Anchorage", "Fairbanks", "Juneau"]),
            CountryRegion(name: "Hawaii", cities: ["Honolulu", "Hilo", "Kailua"]),
            // Midwest
            CountryRegion(name: "Illinois", cities: ["Chicago", "Aurora", "Naperville", "Joliet"]),
            CountryRegion(name: "Ohio", cities: ["Columbus", "Cleveland", "Cincinnati", "Toledo", "Akron"]),
            CountryRegion(name: "Michigan", cities: ["Detroit", "Grand Rapids", "Warren", "Ann Arbor"]),
            CountryRegion(name: "Indiana", cities: ["Indianapolis", "Fort Wayne", "Evansville"]),
            CountryRegion(name: "Wisconsin", cities: ["Milwaukee", "Madison", "Green Bay"]),
            CountryRegion(name: "Minnesota", cities: ["Minneapolis", "Saint Paul", "Rochester"]),
            CountryRegion(name: "Iowa", cities: ["Des Moines", "Cedar Rapids", "Davenport"]),
            CountryRegion(name: "Missouri", cities: ["Kansas City", "St. Louis", "Springfield"]),
            CountryRegion(name: "Kansas", cities: ["Wichita", "Overland Park", "Kansas City"]),
            CountryRegion(name: "Nebraska", cities: ["Omaha", "Lincoln", "Bellevue"]),
            CountryRegion(name: "South Dakota", cities: ["Sioux Falls", "Rapid City", "Aberdeen"]),
            CountryRegion(name: "North Dakota", cities: ["Fargo", "Bismarck", "Grand Forks"]),
            // South
            CountryRegion(name: "Texas", cities: ["Houston", "Dallas", "Austin", "San Antonio", "Fort Worth", "El Paso"]),
            CountryRegion(name: "Florida", cities: ["Miami", "Orlando", "Tampa", "Jacksonville", "Fort Lauderdale"]),
            CountryRegion(name: "Georgia", cities: ["Atlanta", "Augusta", "Columbus", "Savannah"]),
            CountryRegion(name: "North Carolina", cities: ["Charlotte", "Raleigh", "Greensboro", "Durham"]),
            CountryRegion(name: "Virginia", cities: ["Virginia Beach", "Norfolk", "Richmond", "Arlington"]),
            CountryRegion(name: "Tennessee", cities: ["Nashville", "Memphis", "Knoxville", "Chattanooga"]),
            CountryRegion(name: "Louisiana", cities: ["New Orleans", "Baton Rouge", "Shreveport"]),
            CountryRegion(name: "Alabama", cities: ["Birmingham", "Montgomery", "Mobile"]),
            CountryRegion(name: "Mississippi", cities: ["Jackson", "Gulfport", "Southaven"]),
            CountryRegion(name: "Arkansas", cities: ["Little Rock", "Fort Smith", "Fayetteville"]),
            CountryRegion(name: "South Carolina", cities: ["Charleston", "Columbia", "Greenville"]),
            CountryRegion(name: "Kentucky", cities: ["Louisville", "Lexington", "Bowling Green"]),
            CountryRegion(name: "Oklahoma", cities: ["Oklahoma City", "Tulsa", "Norman"]),
            CountryRegion(name: "West Virginia", cities: ["Charleston", "Huntington", "Morgantown"]),
            CountryRegion(name: "Maryland", cities: ["Baltimore", "Columbia", "Germantown"]),
            CountryRegion(name: "Delaware", cities: ["Wilmington", "Dover", "Newark"]),
            // Northeast
            CountryRegion(name: "New York", cities: ["New York City", "Buffalo", "Rochester", "Albany", "Syracuse"]),
            CountryRegion(name: "Pennsylvania", cities: ["Philadelphia", "Pittsburgh", "Allentown", "Erie"]),
            CountryRegion(name: "New Jersey", cities: ["Newark", "Jersey City", "Paterson", "Elizabeth"]),
            CountryRegion(name: "Massachusetts", cities: ["Boston", "Worcester", "Springfield", "Cambridge"]),
            CountryRegion(name: "Connecticut", cities: ["Bridgeport", "New Haven", "Hartford", "Stamford"]),
            CountryRegion(name: "Rhode Island", cities: ["Providence", "Warwick", "Cranston"]),
            CountryRegion(name: "New Hampshire", cities: ["Manchester", "Nashua", "Concord"]),
            CountryRegion(name: "Vermont", cities: ["Burlington", "Rutland", "Montpelier"]),
            CountryRegion(name: "Maine", cities: ["Portland", "Lewiston", "Bangor"])
        ]
    )

    static let canada = Country(
        id: "CA",
        name: "Canada",
        flag: "🇨🇦",
        dialCode: "+1",
        regions: ["Ontario", "Quebec", "British Columbia", "Alberta"],
        detailedRegions: [
            CountryRegion(name: "Ontario", cities: ["Toronto", "Ottawa", "Mississauga"]),
            CountryRegion(name: "Quebec", cities: ["Montreal", "Quebec City"]),
            CountryRegion(name: "British Columbia", cities: ["Vancouver", "Victoria"]),
            CountryRegion(name: "Alberta", cities: ["Calgary", "Edmonton"])
        ]
    )

    static let mexico = Country(
        id: "MX",
        name: "Mexico",
        flag: "🇲🇽",
        dialCode: "+52",
        regions: ["Mexico City", "Jalisco", "Nuevo León", "Yucatán"],
        detailedRegions: [
            CountryRegion(name: "Mexico City", cities: ["Mexico City"]),
            CountryRegion(name: "Jalisco", cities: ["Guadalajara"]),
            CountryRegion(name: "Nuevo León", cities: ["Monterrey"]),
            CountryRegion(name: "Yucatán", cities: ["Mérida"])
        ]
    )

    static let brazil = Country(
        id: "BR",
        name: "Brazil",
        flag: "🇧🇷",
        dialCode: "+55",
        regions: ["São Paulo", "Rio de Janeiro", "Bahia", "Minas Gerais"],
        detailedRegions: [
            CountryRegion(name: "São Paulo", cities: ["São Paulo", "Campinas"]),
            CountryRegion(name: "Rio de Janeiro", cities: ["Rio de Janeiro"]),
            CountryRegion(name: "Bahia", cities: ["Salvador"]),
            CountryRegion(name: "Minas Gerais", cities: ["Belo Horizonte"])
        ]
    )

    static let argentina = Country(
        id: "AR",
        name: "Argentina",
        flag: "🇦🇷",
        dialCode: "+54",
        regions: ["Buenos Aires", "Córdoba", "Santa Fe", "Mendoza"]
    )

    static let chile = Country(
        id: "CL",
        name: "Chile",
        flag: "🇨🇱",
        dialCode: "+56",
        regions: ["Santiago Metropolitan", "Valparaíso", "Biobío"]
    )

    static let colombia = Country(
        id: "CO",
        name: "Colombia",
        flag: "🇨🇴",
        dialCode: "+57",
        regions: ["Bogotá", "Antioquia", "Valle del Cauca", "Atlántico"]
    )

    static let peru = Country(
        id: "PE",
        name: "Peru",
        flag: "🇵🇪",
        dialCode: "+51",
        regions: ["Lima", "Arequipa", "Cusco", "La Libertad"]
    )

    static let venezuela = Country(
        id: "VE",
        name: "Venezuela",
        flag: "🇻🇪",
        dialCode: "+58",
        regions: ["Capital District", "Miranda", "Zulia", "Carabobo"]
    )

    // MARK: - Oceania

    static let australia = Country(
        id: "AU",
        name: "Australia",
        flag: "🇦🇺",
        dialCode: "+61",
        regions: ["New South Wales", "Victoria", "Queensland", "Western Australia"],
        detailedRegions: [
            CountryRegion(name: "New South Wales", cities: ["Sydney", "Newcastle", "Wollongong"]),
            CountryRegion(name: "Victoria", cities: ["Melbourne", "Geelong"]),
            CountryRegion(name: "Queensland", cities: ["Brisbane", "Gold Coast", "Cairns"]),
            CountryRegion(name: "Western Australia", cities: ["Perth"])
        ]
    )

    static let newZealand = Country(
        id: "NZ",
        name: "New Zealand",
        flag: "🇳🇿",
        dialCode: "+64",
        regions: ["Auckland", "Wellington", "Canterbury", "Waikato"]
    )

    // MARK: - Additional Countries (Alphabetical)

    static let additionalCountries: [Country] = [
        // Africa (Additional)
        Country(id: "DZ", name: "Algeria", flag: "🇩🇿", dialCode: "+213", regions: ["Algiers", "Oran", "Constantine"]),
        Country(id: "AO", name: "Angola", flag: "🇦🇴", dialCode: "+244", regions: ["Luanda", "Benguela", "Huambo"]),
        Country(id: "CM", name: "Cameroon", flag: "🇨🇲", dialCode: "+237", regions: ["Centre", "Littoral", "West"]),
        Country(id: "CI", name: "Côte d'Ivoire", flag: "🇨🇮", dialCode: "+225", regions: ["Abidjan", "Yamoussoukro", "Bouaké"]),
        Country(id: "ET", name: "Ethiopia", flag: "🇪🇹", dialCode: "+251", regions: ["Addis Ababa", "Oromia", "Amhara"]),
        Country(id: "MA", name: "Morocco", flag: "🇲🇦", dialCode: "+212", regions: ["Casablanca", "Rabat", "Marrakesh"]),
        Country(id: "MZ", name: "Mozambique", flag: "🇲🇿", dialCode: "+258", regions: ["Maputo", "Sofala", "Nampula"]),
        Country(id: "SN", name: "Senegal", flag: "🇸🇳", dialCode: "+221", regions: ["Dakar", "Thiès", "Saint-Louis"]),
        Country(id: "TZ", name: "Tanzania", flag: "🇹🇿", dialCode: "+255", regions: ["Dar es Salaam", "Mwanza", "Arusha"]),
        Country(id: "TN", name: "Tunisia", flag: "🇹🇳", dialCode: "+216", regions: ["Tunis", "Sfax", "Sousse"]),
        Country(id: "UG", name: "Uganda", flag: "🇺🇬", dialCode: "+256", regions: ["Kampala", "Wakiso", "Mukono"]),
        Country(id: "ZW", name: "Zimbabwe", flag: "🇿🇼", dialCode: "+263", regions: ["Harare", "Bulawayo", "Chitungwiza"]),

        // Asia (Additional)
        Country(id: "AF", name: "Afghanistan", flag: "🇦🇫", dialCode: "+93", regions: ["Kabul", "Herat", "Kandahar"]),
        Country(id: "AM", name: "Armenia", flag: "🇦🇲", dialCode: "+374", regions: ["Yerevan", "Gyumri", "Vanadzor"]),
        Country(id: "AZ", name: "Azerbaijan", flag: "🇦🇿", dialCode: "+994", regions: ["Baku", "Ganja", "Sumqayit"]),
        Country(id: "BH", name: "Bahrain", flag: "🇧🇭", dialCode: "+973", regions: ["Manama", "Riffa", "Muharraq"]),
        Country(id: "BN", name: "Brunei", flag: "🇧🇳", dialCode: "+673", regions: ["Bandar Seri Begawan"]),
        Country(id: "KH", name: "Cambodia", flag: "🇰🇭", dialCode: "+855", regions: ["Phnom Penh", "Siem Reap", "Battambang"]),
        Country(id: "GE", name: "Georgia", flag: "🇬🇪", dialCode: "+995", regions: ["Tbilisi", "Batumi", "Kutaisi"]),
        Country(id: "HK", name: "Hong Kong", flag: "🇭🇰", dialCode: "+852", regions: ["Hong Kong Island", "Kowloon", "New Territories"]),
        Country(id: "IQ", name: "Iraq", flag: "🇮🇶", dialCode: "+964", regions: ["Baghdad", "Basra", "Erbil"]),
        Country(id: "IR", name: "Iran", flag: "🇮🇷", dialCode: "+98", regions: ["Tehran", "Mashhad", "Isfahan"]),
        Country(id: "JO", name: "Jordan", flag: "🇯🇴", dialCode: "+962", regions: ["Amman", "Zarqa", "Irbid"]),
        Country(id: "KZ", name: "Kazakhstan", flag: "🇰🇿", dialCode: "+7", regions: ["Almaty", "Nur-Sultan", "Shymkent"]),
        Country(id: "KW", name: "Kuwait", flag: "🇰🇼", dialCode: "+965", regions: ["Kuwait City", "Hawalli", "Farwaniya"]),
        Country(id: "KG", name: "Kyrgyzstan", flag: "🇰🇬", dialCode: "+996", regions: ["Bishkek", "Osh", "Jalal-Abad"]),
        Country(id: "LA", name: "Laos", flag: "🇱🇦", dialCode: "+856", regions: ["Vientiane", "Luang Prabang", "Pakse"]),
        Country(id: "LB", name: "Lebanon", flag: "🇱🇧", dialCode: "+961", regions: ["Beirut", "Mount Lebanon", "North"]),
        Country(id: "MO", name: "Macau", flag: "🇲🇴", dialCode: "+853", regions: ["Macau Peninsula", "Taipa", "Coloane"]),
        Country(id: "MV", name: "Maldives", flag: "🇲🇻", dialCode: "+960", regions: ["Malé", "Addu City"]),
        Country(id: "MN", name: "Mongolia", flag: "🇲🇳", dialCode: "+976", regions: ["Ulaanbaatar", "Erdenet", "Darkhan"]),
        Country(id: "MM", name: "Myanmar", flag: "🇲🇲", dialCode: "+95", regions: ["Yangon", "Mandalay", "Naypyidaw"]),
        Country(id: "NP", name: "Nepal", flag: "🇳🇵", dialCode: "+977", regions: ["Kathmandu", "Pokhara", "Lalitpur"]),
        Country(id: "OM", name: "Oman", flag: "🇴🇲", dialCode: "+968", regions: ["Muscat", "Salalah", "Sohar"]),
        Country(id: "PS", name: "Palestine", flag: "🇵🇸", dialCode: "+970", regions: ["Gaza", "West Bank", "Jerusalem"]),
        Country(id: "QA", name: "Qatar", flag: "🇶🇦", dialCode: "+974", regions: ["Doha", "Al Rayyan", "Al Wakrah"]),
        Country(id: "LK", name: "Sri Lanka", flag: "🇱🇰", dialCode: "+94", regions: ["Western", "Central", "Southern"]),
        Country(id: "SY", name: "Syria", flag: "🇸🇾", dialCode: "+963", regions: ["Damascus", "Aleppo", "Homs"]),
        Country(id: "TW", name: "Taiwan", flag: "🇹🇼", dialCode: "+886", regions: ["Taipei", "Kaohsiung", "Taichung"]),
        Country(id: "TJ", name: "Tajikistan", flag: "🇹🇯", dialCode: "+992", regions: ["Dushanbe", "Khujand", "Kulob"]),
        Country(id: "TM", name: "Turkmenistan", flag: "🇹🇲", dialCode: "+993", regions: ["Ashgabat", "Türkmenabat", "Daşoguz"]),
        Country(id: "UZ", name: "Uzbekistan", flag: "🇺🇿", dialCode: "+998", regions: ["Tashkent", "Samarkand", "Bukhara"]),
        Country(id: "YE", name: "Yemen", flag: "🇾🇪", dialCode: "+967", regions: ["Sanaa", "Aden", "Taiz"]),

        // Europe (Additional)
        Country(id: "AL", name: "Albania", flag: "🇦🇱", dialCode: "+355", regions: ["Tirana", "Durrës", "Vlorë"]),
        Country(id: "BY", name: "Belarus", flag: "🇧🇾", dialCode: "+375", regions: ["Minsk", "Gomel", "Mogilev"]),
        Country(id: "BA", name: "Bosnia and Herzegovina", flag: "🇧🇦", dialCode: "+387", regions: ["Sarajevo", "Banja Luka", "Tuzla"]),
        Country(id: "BG", name: "Bulgaria", flag: "🇧🇬", dialCode: "+359", regions: ["Sofia", "Plovdiv", "Varna"]),
        Country(id: "HR", name: "Croatia", flag: "🇭🇷", dialCode: "+385", regions: ["Zagreb", "Split", "Rijeka"]),
        Country(id: "CY", name: "Cyprus", flag: "🇨🇾", dialCode: "+357", regions: ["Nicosia", "Limassol", "Larnaca"]),
        Country(id: "EE", name: "Estonia", flag: "🇪🇪", dialCode: "+372", regions: ["Harju", "Tartu", "Ida-Viru"]),
        Country(id: "HU", name: "Hungary", flag: "🇭🇺", dialCode: "+36", regions: ["Budapest", "Pest", "Borsod-Abaúj-Zemplén"]),
        Country(id: "IS", name: "Iceland", flag: "🇮🇸", dialCode: "+354", regions: ["Capital Region", "Southern Peninsula", "Westfjords"]),
        Country(id: "LV", name: "Latvia", flag: "🇱🇻", dialCode: "+371", regions: ["Riga", "Daugavpils", "Liepāja"]),
        Country(id: "LT", name: "Lithuania", flag: "🇱🇹", dialCode: "+370", regions: ["Vilnius", "Kaunas", "Klaipėda"]),
        Country(id: "LU", name: "Luxembourg", flag: "🇱🇺", dialCode: "+352", regions: ["Luxembourg", "Esch-sur-Alzette"]),
        Country(id: "MT", name: "Malta", flag: "🇲🇹", dialCode: "+356", regions: ["Valletta", "Birkirkara", "Sliema"]),
        Country(id: "MD", name: "Moldova", flag: "🇲🇩", dialCode: "+373", regions: ["Chișinău", "Tiraspol", "Bălți"]),
        Country(id: "ME", name: "Montenegro", flag: "🇲🇪", dialCode: "+382", regions: ["Podgorica", "Nikšić", "Herceg Novi"]),
        Country(id: "MK", name: "North Macedonia", flag: "🇲🇰", dialCode: "+389", regions: ["Skopje", "Bitola", "Kumanovo"]),
        Country(id: "RO", name: "Romania", flag: "🇷🇴", dialCode: "+40", regions: ["Bucharest", "Cluj", "Timișoara"]),
        Country(id: "RS", name: "Serbia", flag: "🇷🇸", dialCode: "+381", regions: ["Belgrade", "Novi Sad", "Niš"]),
        Country(id: "SK", name: "Slovakia", flag: "🇸🇰", dialCode: "+421", regions: ["Bratislava", "Košice", "Prešov"]),
        Country(id: "SI", name: "Slovenia", flag: "🇸🇮", dialCode: "+386", regions: ["Ljubljana", "Maribor", "Celje"]),

        // Americas (Additional)
        Country(id: "BO", name: "Bolivia", flag: "🇧🇴", dialCode: "+591", regions: ["La Paz", "Santa Cruz", "Cochabamba"]),
        Country(id: "CR", name: "Costa Rica", flag: "🇨🇷", dialCode: "+506", regions: ["San José", "Alajuela", "Cartago"]),
        Country(id: "CU", name: "Cuba", flag: "🇨🇺", dialCode: "+53", regions: ["Havana", "Santiago de Cuba", "Camagüey"]),
        Country(id: "DO", name: "Dominican Republic", flag: "🇩🇴", dialCode: "+1-809", regions: ["Santo Domingo", "Santiago", "La Vega"]),
        Country(id: "EC", name: "Ecuador", flag: "🇪🇨", dialCode: "+593", regions: ["Pichincha", "Guayas", "Azuay"]),
        Country(id: "SV", name: "El Salvador", flag: "🇸🇻", dialCode: "+503", regions: ["San Salvador", "Santa Ana", "San Miguel"]),
        Country(id: "GT", name: "Guatemala", flag: "🇬🇹", dialCode: "+502", regions: ["Guatemala", "Quetzaltenango", "Escuintla"]),
        Country(id: "HN", name: "Honduras", flag: "🇭🇳", dialCode: "+504", regions: ["Francisco Morazán", "Cortés", "Atlántida"]),
        Country(id: "JM", name: "Jamaica", flag: "🇯🇲", dialCode: "+1-876", regions: ["Kingston", "St. Andrew", "St. Catherine"]),
        Country(id: "NI", name: "Nicaragua", flag: "🇳🇮", dialCode: "+505", regions: ["Managua", "León", "Masaya"]),
        Country(id: "PA", name: "Panama", flag: "🇵🇦", dialCode: "+507", regions: ["Panamá", "Colón", "Chiriquí"]),
        Country(id: "PY", name: "Paraguay", flag: "🇵🇾", dialCode: "+595", regions: ["Asunción", "Central", "Alto Paraná"]),
        Country(id: "PR", name: "Puerto Rico", flag: "🇵🇷", dialCode: "+1-787", regions: ["San Juan", "Bayamón", "Carolina"]),
        Country(id: "TT", name: "Trinidad and Tobago", flag: "🇹🇹", dialCode: "+1-868", regions: ["Port of Spain", "San Fernando", "Chaguanas"]),
        Country(id: "UY", name: "Uruguay", flag: "🇺🇾", dialCode: "+598", regions: ["Montevideo", "Canelones", "Maldonado"]),

        // Oceania (Additional)
        Country(id: "FJ", name: "Fiji", flag: "🇫🇯", dialCode: "+679", regions: ["Central", "Western", "Northern"]),
        Country(id: "PG", name: "Papua New Guinea", flag: "🇵🇬", dialCode: "+675", regions: ["National Capital", "Morobe", "Eastern Highlands"]),
    ]

    // MARK: - All Countries List

    static let allCountries: [Country] = [
        // Primary markets (with detailed cities)
        .nigeria, .southAfrica, .egypt, .kenya, .ghana,
        .china, .india, .japan, .southKorea, .singapore, .thailand, .vietnam, .indonesia, .malaysia, .philippines,
        .pakistan, .bangladesh, .uae, .saudiArabia, .israel, .turkey,
        .uk, .germany, .france, .italy, .spain, .netherlands, .belgium, .switzerland, .austria,
        .sweden, .norway, .denmark, .finland, .poland, .czechia, .portugal, .greece, .russia, .ukraine, .ireland,
        .usa, .canada, .mexico, .brazil, .argentina, .chile, .colombia, .peru, .venezuela,
        .australia, .newZealand
    ] + additionalCountries
}

// MARK: - Helper Extensions

extension Country {
    /// Get all cities for a country (flattened from detailed regions)
    var allCities: [String] {
        guard let detailedRegions = detailedRegions else {
            return []
        }
        return detailedRegions.flatMap { $0.cities }
    }

    /// Get cities for a specific region
    func cities(forRegion regionName: String) -> [String] {
        guard let detailedRegions = detailedRegions else {
            return []
        }
        return detailedRegions.first { $0.name == regionName }?.cities ?? []
    }
}
