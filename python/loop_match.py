import json
import random
from web3 import Web3

contract_path = '../build/contracts/ResourceSharing.json'
ganache_url = 'http://localhost:7545'
print_delimiter = '=========='
max_match_interval = 100 * 1000


class ResourceSharing:
    def __init__(self, contract_addr=''):
        self.contract_addr = contract_addr
        self.contract = None
        self.accounts = None
        self.web3 = None

    def deploy_contract(self):
        web3 = Web3(Web3.HTTPProvider(ganache_url))
        self.web3 = web3
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
        print(f"add provider, name={name}, target={target}, start={start}, end={end}")
        for retry in range(10):
            try:
                self.contract.functions.addProvider(name, target, start, end).transact()
                return
            except Exception as e:
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

    def add_consumer(self, name, budget, duration, deadline):
        print(f"add consumer, name={name}, budget={budget}, duration={duration}, deadline={deadline}")
        for retry in range(10):
            try:
                self.contract.functions.addConsumer(name, budget, duration, deadline).transact()
                return
            except Exception as e:
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

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
        matches = list()
        print(f"\n{print_delimiter} list matches of address {_address} {print_delimiter}")
        idx = 0
        while True:
            try:
                match = self.contract.functions.matchings(_address, idx).call()
                matches.append(match)
                print(match)
                idx += 1

            except Exception as e:
                break
        print(f"//////////////////////////////////////////////////\n")
        return matches

    @staticmethod
    def is_byte32_empty(_id):
        return Web3.toHex(_id) == '0x0000000000000000000000000000000000000000000000000000000000000000'

    def set_address(self, _address):
        self.web3.eth.defaultAccount = _address


if __name__ == '__main__':
    rs = ResourceSharing()
    rs.deploy_contract()

    num = 100
    budget_range = 50
    start_base = 3000000000
    start_range = 10000
    end_base = 4000000000
    end_range = 10000
    duration_base = int((end_base - start_base) * 3 / 4)
    duration_range = int((end_base - start_base) * 1 / 4)
    deadline_base = 5000000000

    for j in range(1):
        # add providers
        rs.set_address(rs.accounts[0])
        for i in range(num):
            rand = random.random()
            rs.add_provider(f"provider #{i}", int(budget_range * rand), int(start_base + start_range * rand),
                            int(end_base + end_range * rand))

        rs.set_address(rs.accounts[1])
        # add consumers
        for i in range(num):
            rand = random.random()
            rs.add_consumer(f"consumer #{i}", int(budget_range * rand), int(duration_base + duration_range * rand),
                            deadline_base)

        matches_from = rs.list_matches(rs.accounts[0])
        matches_to = rs.list_matches(rs.accounts[1])
        if len(matches_from) != len(matches_to):
            print(f"Error! len_matches_from={len(matches_from)}, len_matches_to={len(matches_to)}")
        print(f"Engagement:\ntotal={num}, matches={len(matches_from)}, "
              f"engagement_rate={round(len(matches_from) / num * 100, 5)} % ")
