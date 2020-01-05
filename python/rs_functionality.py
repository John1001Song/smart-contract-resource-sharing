import json
from web3 import Web3

ganache_url = 'http://localhost:7545'
web3 = Web3(Web3.HTTPProvider(ganache_url))

path = '../build/contracts/ResourceSharing.json'
with open(path) as f:
    config = json.loads(f.read())

print(web3.isConnected())
print(web3.eth.blockNumber)
print(web3.eth.accounts)

web3.eth.defaultAccount = web3.eth.accounts[0]
rs = web3.eth.contract(abi=config['abi'], bytecode=config['bytecode'])
tx_hash = rs.constructor().transact()
tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)

contract = web3.eth.contract(
    address=tx_receipt.contractAddress,
    abi=config['abi'],
)

print(tx_receipt.contractAddress)
print(contract.functions.maxMatchInterval().call())

start = 7999999999
end = 9999999999
print(contract.functions.addProvider("hello", "SF", 3, start, end).call())
head, a = contract.functions.getProviderHead("SF").call()
print(head)
head = Web3.toBytes(hexstr='0x6039751ff8d02567d831c7decbbb523e641b536934a739af072093d5401f357a')
print(contract.functions.getProviderName("SF", head).call())
print(contract.functions.getLatest().call())
