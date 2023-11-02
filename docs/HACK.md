# Code structure of the repository

```
├── src
│   ├── extensions              <-- helpers and shared contracts
│   ├── interfaces              <-- interfaces
│   ├── libraries               <-- libraries
│   ├── mainchain               <-- contracts should only deployed on mainchain
│   ├── mocks                   <-- mock contracts used in tests
│   ├── multi-chains            <-- Ronin trusted orgs contracts
│   ├── precompile-usages       <-- wrapper for precompiled calls
│   └── ronin                       <-- contracts should only deployed on Ronin chain
│       ├── bridge-tracking             <-- slashing and credit score contracts
│       ├── gateway                     <-- gateway contracts
|       └── ...                         <-- other single file contracts
├── docs                        <-- documentation
├── scripts                     <-- Foundry scripts
└── test                        <-- tests
```