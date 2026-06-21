# FRONTEND: https://a.obws.fun/
- OS BOTÕES:: admin, (sair) (dashboard) etc...
estão completamente tortos, e estão no canto superior esquerdo! 
- ainda não foi aplicado o: HARBOR STYLE ao frontend! -> APLIQUE!
- frontend ainda não está como uma aplicação web! e não está responsivo! (ajuste imediato!)
------- EXEMPLO DE COMO DEVE SER A COR EXATA DO FRONTEND:
<!DOCTYPE html>
<html lang="pt-br" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard C2 | Harbor Style</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap" rel="stylesheet">
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        harbor: {
                            bg: '#0b1a23',
                            sidebar: '#152a36',
                            card: '#1c313d',
                            border: '#2e4958',
                            accent: '#4ca5cc',
                            text: '#e2e8f0'
                        }
                    }
                }
            }
        }
    </script>
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #0b1a23; color: #e2e8f0; }
        .harbor-card { background: #1c313d; border: 1px solid #2e4958; border-radius: 4px; }
        .sidebar-item:hover { background: #1c313d; }
    </style>
</head>
<body class="min-h-screen flex text-sm">

    <aside class="w-64 bg-[#152a36] border-r border-[#2e4958] flex flex-col">
        <div class="h-16 flex items-center px-6 font-semibold border-b border-[#2e4958] text-white">
            Harbor C2
        </div>
        <nav class="flex-1 py-4">
            <a href="#" class="block py-2.5 px-6 bg-[#1c313d] text-white border-l-2 border-harbor-accent">Dashboard</a>
            <a href="#" class="block py-2.5 px-6 hover:bg-[#1c313d] transition">Agentes</a>
            <a href="#" class="block py-2.5 px-6 hover:bg-[#1c313d] transition">Configurações</a>
        </nav>
    </aside>

    <main class="flex-1">
        <header class="h-16 border-b border-[#2e4958] flex items-center justify-between px-8 bg-[#152a36]">
            <h1 class="text-lg font-medium">Dashboard Overview</h1>
            <div class="text-xs text-gray-400">admin • <button class="text-red-400 ml-3 hover:underline">Sair</button></div>
        </header>

        <div class="p-8">
            <!-- Stats -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                <div class="harbor-card p-6">
                    <p class="text-gray-400 uppercase text-xs tracking-wider mb-2">Registros de Agentes</p>
                    <h2 class="text-4xl font-bold text-harbor-accent">2</h2>
                </div>
                <div class="harbor-card p-6">
                    <p class="text-gray-400 uppercase text-xs tracking-wider mb-2">Comandos Pendentes</p>
                    <h2 class="text-4xl font-bold text-yellow-500">10</h2>
                </div>
            </div>

            <!-- Agents -->
            <div class="harbor-card">
                <div class="p-4 border-b border-[#2e4958] font-medium text-gray-300">Agentes Ativos</div>
                <div class="divide-y divide-[#2e4958]">
                    <div class="p-6 flex justify-between items-center hover:bg-[#203643] transition">
                        <div>
                            <p class="font-bold text-white">OBWS <span class="text-xs text-gray-500 ml-2">b2efb7...</span></p>
                            <p class="text-xs text-gray-400 mt-1">Rocky Linux 9.4 | 127.0.0.1:34540</p>
                        </div>
                        <button class="bg-[#4ca5cc] hover:bg-[#3d8aa8] text-white px-4 py-1.5 text-xs rounded transition">Gerenciar</button>
                    </div>
                    <div class="p-6 flex justify-between items-center hover:bg-[#203643] transition">
                        <div>
                            <p class="font-bold text-white">rsdenck-dektop <span class="text-xs text-gray-500 ml-2">f41494...</span></p>
                            <p class="text-xs text-gray-400 mt-1">Zorin OS 17.3 | 127.0.0.1:43082</p>
                        </div>
                        <button class="bg-[#4ca5cc] hover:bg-[#3d8aa8] text-white px-4 py-1.5 text-xs rounded transition">Gerenciar</button>
                    </div>
                </div>
            </div>
        </div>
    </main>

</body>
</html>
