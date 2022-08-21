// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * Athlete Showcase v.0000001e18-alpha
 * by 0xriptide at ethMexico Aug '22
 *
 * Allows permissionless public funding of varsity and collegiate athletes in Mexico (and beyond).
 * A capital provider (sponsor) is rewarded with an NFT representing either 1) an active Superfluid
 * stream to the athlete or 2) a deposit of USDC/DAI to this contract which is converted to Superfluid
 * tokens and immediately streamed to the athlete.
 * 
 * Built using Superfluid, Chainlink, and IPFS on Polygon.
 */

pragma solidity ^0.8.14;
 
import { ISuperfluid, ISuperfluidToken, ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol"; //"@superfluid-finance/ethereum-monorepo/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { CFAv1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./IERC20.sol";
import "./INFT.sol";

contract AthleteFunder {

    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;
    AggregatorV3Interface internal priceFeed;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    event FixedDeposit(address funder, address athlete, address token, uint8 term, uint8 tier);
    event SponsorFlowStarted(address funder, address athlete, address token, int96 rate);
    event FlowRateUpdated(int96 newRate);
    event AthleteStatusUpdated(bool active);
    event AthleteRemoved(address wallet);
    event AthleteAdded(address wallet, string name);
    event FlowStopped(address wallet, address token);

    struct athleteInfo {
        string name;
        string city;
        string state;
        string school;
        bool active;
        uint8 activeFlows;
        uint32 dob;
        uint8 sport;
    }

    mapping(address => athleteInfo) public athlete;
    mapping(address => mapping(address => uint)) public athleteBalances;

    // Keep track of terms for each stream specified by the sponsor.
    // Mapping layout is [sender][athlete][token][terms][nonce]
    mapping(address => mapping(address => mapping(address => mapping(uint => string)))) public flowTerms; 

    mapping(uint8   => string) public sport;
    mapping(uint8   => string) public tier;
    mapping(uint8   => string) public term;

    address public owner;
    address public athleteNFT;

    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;  // 6 decimals
    address public constant USDCx = 0xCAa7349CEA390F89641fe306D93591f87595dc1F; // 18 decimals
    address public constant DAI  = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;  // 18 decimals
    address public constant DAIx = 0x1305F6B6Df9Dc47159D12Eb7aC2804d4A33173c2;  // 18 decimals

    // Monthly living costs in Mexico range between ~5k MXN to ~10k MXN
    uint public constant BASIC_DAILY_FUNDING   = 150;                        // MXN per month
    uint public constant PREM_DAILY_FUNDING    = 300;                        // MXN per month
    uint public constant BASIC_MONTHLY_FUNDING = BASIC_DAILY_FUNDING*30;     // MXN per month
    uint public constant PREM_MONTHLY_FUNDING  = PREM_DAILY_FUNDING*30;      // MXN per month
    uint public constant BASIC_YEARLY_FUNDING  = BASIC_MONTHLY_FUNDING*12;   // MXN per year
    uint public constant PREM_YEARLY_FUNDING   = PREM_MONTHLY_FUNDING*12;    // MXN per year

    // 100 wei per second default rate for stream from this contract to athlete
    // can be modified by owner using setFluidRate()

    int96 flowRate = 100; 
    uint nonce;

    constructor(address _athleteNFT, ISuperfluid host) {
        owner = msg.sender;
        athleteNFT = _athleteNFT;

        // Used for our MXN/USD price feed
        priceFeed = AggregatorV3Interface(0x2E2Ed40Fc4f1774Def278830F8fe3b6e77956Ec8);

        sport[0] = "Soccer";
        sport[1] = "Rugby";
        sport[2] = "Baseball";
        sport[3] = "Basketball";

        tier[0]  = "Basic";
        tier[1]  = "Premium";

        term[0]  = "Day";
        term[1]  = "Month";
        term[2]  = "Year";

        // Set up Superfluid library
        cfaV1 = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(host.getAgreementClass(
                        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                ))
            )
        );
    }

    /**
     * @dev Allows a sponsor to create a stream to the athlete with our contract acting
     * only as a middleman. Thus if sponsor decides to stop the stream due to
     * any reason he is able to immediately do so without having token locked up in our contract.
     */  
    function fundFixed(uint8 _term,uint8 _tier, address _athlete, address _token) external {
        require(athlete[_athlete].active, "Athlete not active");

        uint amount;

        if(_tier == 0 && _term == 0) { amount = BASIC_DAILY_FUNDING; }
        if(_tier == 0 && _term == 1) { amount = BASIC_MONTHLY_FUNDING; }        
        if(_tier == 0 && _term == 2) { amount = BASIC_YEARLY_FUNDING; }  

        if(_tier == 1 && _term == 0) { amount = PREM_DAILY_FUNDING; }
        if(_tier == 1 && _term == 1) { amount = PREM_MONTHLY_FUNDING; }        
        if(_tier == 1 && _term == 2) { amount = PREM_YEARLY_FUNDING; }

        require(amount > 0, "Invalid term or tier");

        // Fetch MXN/USD Chainlink feed
        int price = (getLatestPrice() / 1e8);
        if(price <= 0) { revert("Price feed invalid"); }

        if(_token == USDC) {
            amount = (amount * uint(price)) ** 1e6;
            IERC20(_token).approve(USDCx, amount);
        }
        else if(_token == DAI) {
            amount = (amount * uint(price)) ** 1e18;
            IERC20(_token).approve(DAIx, amount);
        }
        else { revert("Unsupported token"); }

        IERC20(_token).approve(address(this), amount);
        IERC20(_token).transferFrom(msg.sender, address(this), amount);

        ISuperToken(_token).upgrade(amount);

        // Add deposit to the athlete's balance
        athleteBalances[_athlete][_token] += amount;
        athlete[_athlete].activeFlows++;

        // Mint NFT to sender for funding the athlete
        INFT(athleteNFT).nftMint(msg.sender);

        // Create a Superfluid stream from this contract to the athlete at the current flow rate
        cfaV1.createFlow(_athlete, ISuperfluidToken(_token), flowRate);

        emit FixedDeposit(msg.sender, _athlete, _token, _term, _tier);
        emit SponsorFlowStarted(msg.sender, _athlete, _token, flowRate);
    }
    
    /**
     * @dev Allows a sponsor to create a stream to the athlete with our contract acting
     * only as a middleman. Thus if sponsor decides to stop the stream due to
     * any reason he is able to immediately do so without having token locked up in our contract.
     *
     * Emits a {SponsorFlowStarted} event.
     */    
    function fundFlow(int96 _rate, address _athlete, ISuperfluidToken _token, uint _amount, string memory _terms) external {
        require(athlete[_athlete].active, "Athlete not active");
        require(_rate > 0, "Rate must be > 0");
        require(_amount >0, "Amount must be > 0");
        require(address(_token) == USDCx || address(_token) == DAIx, "Unsupported Superfluid token");

        // Record flow agreement terms specified by sponsor
        // Example would be: Wear our branded shirt when you play. At least X times per season.
        flowTerms[msg.sender][_athlete][address(_token)][nonce] = _terms;
        athlete[_athlete].activeFlows++;

        // Set up approval for this contract to create & delete a stream from the sponsor
        cfaV1.updateFlowOperatorPermissions(address(this), _token, 5, _rate);
        cfaV1.createFlowByOperator(msg.sender, _athlete, _token, _rate);

        nonce++;

        emit SponsorFlowStarted(msg.sender, _athlete, address(_token), _rate);
    }

    /**
     * @dev Stops an active stream from `msg.sender` to `_athlete`.
     */
    function stopFlow(address _athlete, ISuperfluidToken _token) external {
        // Sponsor is able to cancel his stream anytime
        cfaV1.deleteFlowByOperator(msg.sender, _athlete, _token);
        athlete[_athlete].activeFlows--;

        emit FlowStopped(_athlete, address(_token));
    }

    /**
     * @dev Returns the latest price from MXN/USD Chainlink feed
     */
    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }

    /*****************************
     *                           *
     * @dev Restricted Functions *
     *                           *
     *****************************/

    /**
     * @dev Adds a new athlete
     */
    function addAthlete (
        address _wallet,
        string memory _name,
        string memory _city,
        string memory _state,
        string memory _school,
        bool _active,
        uint8 _activeFlows,
        uint32 _dob,
        uint8 _sport) external onlyOwner {

        athlete[_wallet].name   = _name;
        athlete[_wallet].city   = _city;
        athlete[_wallet].state  = _state;
        athlete[_wallet].school = _school;
        athlete[_wallet].active = _active;
        athlete[_wallet].activeFlows = _activeFlows;
        athlete[_wallet].dob    = _dob;
        athlete[_wallet].sport  = _sport;

        emit AthleteAdded(_wallet, _name);
    }

    /**
     * @dev Removes an existing athlete
     */
    function removeAthlete(address _wallet) external onlyOwner {
        delete athlete[_wallet];

        emit AthleteRemoved(_wallet);
    }

    /**
     * @dev Sets an existing athlete's active status
     */
    function updateAthleteStatus(address _wallet, bool _active) external onlyOwner {
        athlete[_wallet].active = _active;

        emit AthleteStatusUpdated(_active);
    }

    /**
     * @dev Sets the default flow rate for streams originating from one-off sponsorships
     * deposited to this contract on behalf of an athlete
     */
    function setFlowRate(int96 _newRate) external onlyOwner {
        require(_newRate > 0, "Rate must be greater than zero");
        flowRate = _newRate;

        emit FlowRateUpdated(_newRate);
    }
}