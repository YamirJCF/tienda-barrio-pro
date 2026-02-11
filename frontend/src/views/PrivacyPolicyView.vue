<template>
  <div class="min-h-screen bg-gray-50 py-8 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto bg-white shadow sm:rounded-lg overflow-hidden">
      <div class="px-4 py-5 sm:px-6 bg-blue-600">
        <h3 class="text-lg leading-6 font-medium text-white">
          Política de Tratamiento de Datos Personales
        </h3>
        <p class="mt-1 max-w-2xl text-sm text-blue-100">
          Ley 1581 de 2012 (Habeas Data) - Colombia
        </p>
      </div>
      <div class="px-4 py-5 sm:p-6 prose prose-blue max-w-none">
        
        <p class="text-sm text-gray-500 mb-6">
          <strong>Fecha de Vigencia:</strong> 11 de Febrero de 2026<br>
          <strong>Responsable:</strong> Tienda de Barrio Pro
        </p>

        <h4>1. Tratamiento y Finalidad</h4>
        <p>
          Los datos personales recolectados serán utilizados exclusivamente para la operación de la plataforma, 
          gestión de ventas, inventarios y seguridad de la cuenta. 
          <strong>No compartimos datos con terceros publicitarios.</strong>
        </p>

        <h4>2. Derechos del Titular</h4>
        <ul class="list-disc pl-5 space-y-1">
          <li>Conocer, actualizar y rectificar sus datos.</li>
          <li>Solicitar prueba de autorización.</li>
          <li>Revocar la autorización o solicitar supresión.</li>
          <li>Acceder gratuitamente a sus datos.</li>
        </ul>

        <h4>3. Canales de Atención</h4>
        <p>
          Para ejercer sus derechos, contáctenos en: <a href="mailto:soporte@tiendadebarrio.pro" class="text-blue-600 hover:underline">soporte@tiendadebarrio.pro</a>
        </p>

        <div class="mt-8 pt-4 border-t border-gray-200">
          <router-link 
            to="/login" 
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Volver al Inicio
          </router-link>
        </div>

      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Static content view
</script>
