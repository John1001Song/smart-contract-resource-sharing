import json
from web3 import Web3

contract_path = '../build/contracts/ResourceSharing.json'
ganache_url = 'http://localhost:7545'
print_delimiter = '=========='


class ResourceSharing:
    def __init__(self, contract_addr=''):
        self.contract_addr = contract_addr
        self.contract = None
        self.accounts = None

    def deploy_contract(self):
        web3 = Web3(Web3.HTTPProvider(ganache_url))
        if self.contract_addr == "":
            with open(contract_path) as f:
                config = json.loads(f.read())
            print(f"connected: {web3.isConnected()}")
            print(f"block number: {web3.eth.blockNumber}")
            print(f"accounts: {web3.eth.accounts}")
            self.accounts = web3.eth.accounts
            web3.eth.defaultAccount = web3.eth.accounts[0]
            rs = web3.eth.contract(abi=config['abi'], bytecode=config['bytecode'])
            tx_hash = rs.constructor().transact()
            tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
            self.contract_addr = tx_receipt.contractAddress

        # TODO: link current contract
        self.contract = web3.eth.contract(
            address=self.contract_addr,
            abi=config['abi'],
        )
        print(f"\ncontract deployed!\ncontract address: {self.contract_addr}\n")

    def add_provider(self, name, target, start, end):
        # print(contract.functions.addProvider("hello", 1, 7999999999, 9999999999).transact())
        print(self.contract.functions.addProvider(name, target, start, end).transact())

    def add_consumer(self, name, budget, duration, deadline):
        # print(contract.functions.addConsumer("world", 1, 100, 9999999999).transact())
        print(self.contract.functions.addConsumer(name, budget, duration, deadline).transact())

    def get_head(self):
        return self.contract.functions.head().call()

    def get_provider(self, _id):
        return self.contract.functions.providerList(_id).call()

    def list_providers(self):
        _id = self.contract.functions.head().call()
        print(f"\n{print_delimiter} list providers {print_delimiter}")
        while True:
            if self.is_byte32_empty(_id):
                break
            provider = self.get_provider(_id)
            print(f"name={provider[2]}, address={provider[3]}, target={provider[4]}, start={provider[5]}, "
                  f"end={provider[6]}, id={provider[0]}, next={provider[1]}")
            _id = provider[1]

        print(f"//////////////////////////////////////////////////\n")

    def list_matches(self, _address):
        print(f"\n{print_delimiter} list matches of address {_address} {print_delimiter}")
        idx = 0
        while True:
            try:
                print(self.contract.functions.matchings(_address, idx).call())
                idx += 1

            except Exception as e:
                break
        print(f"//////////////////////////////////////////////////\n")

    @staticmethod
    def is_byte32_empty(_id):
        return Web3.toHex(_id) == '0x0000000000000000000000000000000000000000000000000000000000000000'


if __name__ == '__main__':
    rs = ResourceSharing()
    rs.deploy_contract()
    rs.add_provider("hello", 1, 7999999999, 9999999999)
    rs.add_provider("world", 2, 8000000000, 9999999999)
    rs.add_consumer("consumer1", 1, 100, 9999999999)
    rs.list_providers()
    rs.list_matches(rs.accounts[0])
