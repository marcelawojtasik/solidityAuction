// SPDX-License-Identifier: MIT
//0x9063D68309ed1CeC2B18aF4227eCeC4178341868
//0x403c96Bbd182A38aDB9d5a0C999415f538531aD0

pragma solidity >0.8.0;

contract Auction{
    //Variables de estado
    uint256 finishTimestamp; 
    uint256 durationInSeconds; 
    uint256 public extraTime = 1 minutes;
    uint256 public maxBid; 
    address public maxBidder; 
    address private owner; //quien deploya el contract
    address public beneficiary; //propietario del bien subastado
    bool refundsDone; 
    

    //Metodo constructor
    constructor(uint256 durationInMinutes, address _beneficiary){
        durationInSeconds = durationInMinutes*60;
        finishTimestamp = block.timestamp + durationInSeconds;
        owner = msg.sender;
        beneficiary = _beneficiary;        
    }
    
    //Eventos
    event NewBidAccepted (address indexed bidder, uint256 bid, uint256 date); //oferta valida aceptada
    event AuctionEnded(address winner, uint256 bid); //subasta finalizada
    event BidRefunded(address bidder, uint256 bid); //se devuelven los bids no retirados previamente por bidders
    event ExtraTimeGranted(uint256 date); //se comunica que se ha concedido tiempo extra a la subasta

    //Estructura de ofertas
    struct Bid{
        address bidder;
        uint256 amount;
        uint256 date;
    }

    //Arrays
    Bid[] public bid;
    address[] public bidders;
    
    //Mappings 
    mapping(address => Bid) bids; 
    mapping(address => uint256) acumulatedBids;

    //Modificadores de acceso
    modifier onlyOwner(){ 
        require(msg.sender==owner, "You do not have permission to transfer the winning auction amount.");
        _;
    }

    modifier auctionEnded(){ 
        require(block.timestamp >= finishTimestamp, "Action not allowed, auction is still active.");
        _;
    }


    //Metodos de la subasta

    /* makeBid: 
    -se acepta la oferta si es mayor a 0 y mayor a la anterior en un 5%
    -si falta menos de un minuto para que finalice y se acepta una oferta, se concede 1' extra
    -se acumulan las ofertas x bidder, para que en el caso de no retirar parciales previo a la finalizacion y no resulten ganadores, el owner les devuelva el total
    -se almacenan en un array los datos de la nueva Bid
    */
    function makeBid() external payable {
        
        uint256 amount = msg.value;
        address bidder = msg.sender;
        uint256 date = block.timestamp;

        require(bidder != owner, "You are the owner, you are not allowed to bid");
        require(block.timestamp < finishTimestamp, "The auction has ended"); 
        require(amount>0, "Please provide a valid amount");
        require((amount > (maxBid * 105/100)), "Your bid must be at least a 5% higher than current maxBid");

            if(finishTimestamp - date <= 1 minutes){
                finishTimestamp += extraTime;
                emit ExtraTimeGranted(date);
            }
            acumulatedBids[bidder] += amount; 
            maxBid = amount;
            maxBidder = bidder;
            emit NewBidAccepted(bidder, amount, date);
            bid.push(Bid(bidder, amount, date));     
            bidders.push(bidder);             
            bids[bidder] = Bid(bidder, amount, date);
    } 
    
    /* withdrawPreviousBid:
    -Permite a cada oferente retirar oferta previa realizada si no es la mas alta al momento
    */
    function withdrawPreviousBid() public {
        address bidder = msg.sender;
        require(bids[bidder].amount > 0, "There is no pending offer to withdraw.");
        require(bidder != maxBidder, "It is not possible to withdraw the winning offer.");    
        uint256 withdrawAmount =bids[bidder].amount;
        bids[bidder].amount = 0;
        payable(bidder).transfer(withdrawAmount); 
    }

    /* refundNonWinningBids:
    -Permite al owner devolver bids no ganadores que no hayan sido retirados previamente por su bidder
    -Comunica que se han devuelto bids 
    */
    function refundNonWinningBids()public onlyOwner auctionEnded{
        
        for (uint256 i=0; i <bidders.length; i++) {
            address bidder = bidders[i];
            if(bidder==maxBidder){
                continue;
            } 
            uint256 withdrawAmount = acumulatedBids[bidder];
            if(withdrawAmount > 0){
                acumulatedBids[bidder]=0;
                
                payable(bidder).transfer(withdrawAmount);
                emit BidRefunded(bidder, withdrawAmount);
            }
        } 
        refundsDone = true;
    }

    /* transferAuctionFunds:
    -Permite al owner pagar al beneficiario el monto ganador de la subasta, luego de devolver los bids no ganadores
    -Comunica ganador y bid ganadora
    */
    function transferAuctionFunds()external onlyOwner auctionEnded {        
        require(refundsDone, "Please refund non-Winning Bids first");
        emit AuctionEnded(maxBidder, maxBid);
        payable(beneficiary).transfer(maxBid);
        maxBid =0;        
        maxBidder = address(0);       
    }    

    
//https://sepolia.scrollscan.com/address/0x403c96bbd182a38adb9d5a0c999415f538531ad0

}